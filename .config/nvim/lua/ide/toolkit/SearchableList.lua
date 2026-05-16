-- SearchableList: base class for searchable picker dialogs.
-- Provides input handling, scrollable list, navigation, reactive rendering.
-- Subclassed by FilePicker, GrepPicker, SelectPicker.

local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Shadow = require 'ide.toolkit.Shadow'

local SearchableList = Class('SearchableList')

---@param opts { title?: string, width?: number, height?: number, on_select?: function, on_close?: function, preview?: boolean }
function SearchableList:init(opts)
    opts = opts or {}
    self._title = opts.title or 'Search'
    self._width = opts.width or 0.6
    self._height = opts.height or 0.5
    self._on_select = opts.on_select
    self._on_close_cb = opts.on_close
    self._query = ''
    self._selected = 1
    self._scroll = 0
    self._buf = nil  ---@type Buffer|nil
    self._win = nil  ---@type Window|nil
    self._shadow = nil
    self._ns = nil
    self._mounted = false
    self._show_preview = opts.preview == true
    self._preview_win = nil ---@type Window|nil
    self._preview_buf = nil ---@type Buffer|nil
    self._preview_path_cache = nil ---@type string|nil
end

--- Override: return the current list of items to display (after filtering).
---@return table[]
function SearchableList:items()
    return {}
end

--- Override: return total item count (before filtering, for footer display).
---@return integer
function SearchableList:total_count()
    return #self:items()
end

--- Override: called when query changes. Subclass filters its data.
---@param query string
function SearchableList:on_query_change(query) end

--- Override: return VNode children for a single item row.
--- Each child is a { type = 'text', text = '...', hl = '...' } node.
---@param item table
---@param width integer
---@return table[] # array of VNode children
function SearchableList:render_item(item, width)
    return { { type = 'text', text = tostring(item) } }
end

--- Override: return preview info for an item.
--- Subclasses return { path = string, line? = integer } or nil to skip.
---@param item table
---@return { path: string, line?: integer }|nil
function SearchableList:preview_path(item)
    return nil
end

--- Override: called when an item is selected (Enter/click).
---@param item table
function SearchableList:on_submit(item)
    if self._on_select then
        vim.schedule(function() self._on_select(item) end)
    end
end

function SearchableList:show()
    if self._mounted then return end

    local ew = Window.editor_width()
    local eh = Window.editor_height()
    local total_w = self._width <= 1 and math.floor(ew * self._width) or self._width
    local h = self._height <= 1 and math.floor(eh * self._height) or self._height

    -- When preview is active, widen the total area and split it
    local has_preview = self._show_preview
    local list_w, preview_w
    if has_preview then
        total_w = math.max(total_w, math.floor(ew * 0.85))
        list_w = math.floor(total_w * 0.4)
        preview_w = total_w - list_w - 1 -- 1 col gap
    else
        list_w = total_w
        preview_w = 0
    end

    local row = math.floor((eh - h) / 2)
    local col = math.floor((ew - total_w) / 2)

    self._shadow = Shadow.for_float(row, col, total_w + 2, h + 2, 199)
    self._buf = Buffer.create({ listed = false, scratch = true })
    self._buf:set_option('bufhidden', 'wipe')
    self._buf:set_option('filetype', 'ide-searchable-list')
    self._ns = Buffer.create_namespace('ide_searchable_list')

    self._win = Window.open_float(self._buf, {
        relative = 'editor',
        row = row, col = col,
        width = list_w, height = h,
        border = { '╔', '═', '╗', '║', '╝', '═', '╚', '║' },
        title = { { '[■]', 'IDEWinButton' }, { '═', 'IDEDialogBorder' }, { ' ' .. self._title .. ' ', 'IDEDialogTitle' } },
        title_pos = 'left',
        style = 'minimal',
        zindex = 200,
        enter = true,
    })
    self._mounted = true

    self._win:set_option('cursorline', false)
    self._win:set_option('wrap', false)
    self._win:set_option('winhl',
        'Normal:IDEDialogNormal,FloatBorder:IDEDialogBorder,Cursor:IDEPanelHiddenCursor')
    self._win:set_option('winblend', 0)

    -- Create preview window if enabled
    if has_preview then
        self:_create_preview_window(row, col + list_w + 2 + 1, preview_w, h)
    end

    -- Hide cursor
    IDE.ui:hide_cursor()

    self:_render()
    self:_bind_keys()

    local sl = self
    vim.api.nvim_create_autocmd('WinLeave', {
        buffer = self._buf:id(),
        callback = function()
            vim.defer_fn(function()
                if not sl._mounted then return end
                if not sl._win or not sl._win:is_valid() then return end
                local cur = vim.api.nvim_get_current_win()
                if cur == sl._win:id() then return end
                -- Don't close if focus went to our preview window
                if sl._preview_win and sl._preview_win:is_valid() and cur == sl._preview_win:id() then
                    sl._win:focus()
                    return
                end
                sl:close()
            end, 100)
        end,
    })
end

--- Create the preview floating window.
---@param row integer
---@param col integer
---@param w integer
---@param h integer
function SearchableList:_create_preview_window(row, col, w, h)
    self._preview_buf = Buffer.create({ listed = false, scratch = true })
    self._preview_buf:set_option('bufhidden', 'wipe')

    self._preview_win = Window.open_float(self._preview_buf, {
        relative = 'editor',
        row = row, col = col,
        width = w, height = h,
        border = { '╔', '═', '╗', '║', '╝', '═', '╚', '║' },
        title = { { ' Preview ', 'IDEDialogTitle' } },
        title_pos = 'center',
        style = 'minimal',
        zindex = 200,
        focusable = false,
    })
    self._preview_win:set_option('cursorline', true)
    self._preview_win:set_option('wrap', false)
    self._preview_win:set_option('number', true)
    self._preview_win:set_option('signcolumn', 'no')
    self._preview_win:set_option('winhl',
        'Normal:IDEDialogNormal,FloatBorder:IDEDialogBorder,CursorLine:IDEDialogListSelected')
    self._preview_win:set_option('winblend', 0)
end

--- Close and clean up the preview window and buffer.
function SearchableList:_close_preview()
    if self._preview_win and self._preview_win:is_valid() then
        self._preview_win:close(true)
    end
    if self._preview_buf and self._preview_buf:is_valid() then
        self._preview_buf:close(true)
    end
    self._preview_win = nil
    self._preview_buf = nil
    self._preview_path_cache = nil
end

--- Update the preview pane to show the given file.
function SearchableList:_update_preview()
    if not self._show_preview then return end
    if not self._preview_win or not self._preview_win:is_valid() then return end

    local items = self:items()
    local item = items[self._selected]
    if not item then
        -- Clear preview when no item selected
        if self._preview_buf and self._preview_buf:is_valid() then
            vim.bo[self._preview_buf:id()].modifiable = true
            self._preview_buf:set_lines(0, -1, { '', '  No file selected' })
            vim.bo[self._preview_buf:id()].modifiable = false
            self._preview_win:update_config({
                relative = 'editor',
                title = { { ' Preview ', 'IDEDialogTitle' } },
                title_pos = 'center',
            })
        end
        self._preview_path_cache = nil
        return
    end

    local info = self:preview_path(item)
    if not info then return end

    local path = info.path
    local target_line = info.line

    -- Build a cache key so we don't reload the same file on every render
    local cache_key = path .. ':' .. (target_line or 0)
    if cache_key == self._preview_path_cache then return end
    self._preview_path_cache = cache_key

    -- Update title to show file name
    local display_name = vim.fs.basename(path) or path
    self._preview_win:update_config({
        relative = 'editor',
        title = { { ' ' .. display_name .. ' ', 'IDEDialogTitle' } },
        title_pos = 'center',
    })

    -- Read file content
    local lines = {}
    local ok_read, read_lines = pcall(function()
        local f = io.open(path, 'r')
        if not f then return nil end
        local content = f:read('*a')
        f:close()
        return vim.split(content, '\n', { plain = true })
    end)

    if ok_read and read_lines then
        lines = read_lines
    else
        lines = { '', '  Unable to read file' }
    end

    -- Limit preview to a reasonable number of lines
    local max_lines = 5000
    if #lines > max_lines then
        lines = vim.list_slice(lines, 1, max_lines)
        lines[#lines + 1] = ''
        lines[#lines + 1] = '  ... (truncated)'
    end

    -- We need a fresh buffer for each file to get proper syntax highlighting.
    -- Create a new buffer, load content, set filetype, then swap it into the window.
    local new_buf = Buffer.create({ listed = false, scratch = true })
    new_buf:set_option('bufhidden', 'wipe')
    new_buf:set_option('modifiable', true)
    new_buf:set_lines(0, -1, lines)
    new_buf:set_option('modifiable', false)

    -- Detect filetype and apply it for syntax highlighting
    local ft = vim.filetype.match({ filename = path })
    if ft then
        new_buf:set_option('filetype', ft)
    end

    -- Swap buffer in the preview window
    self._preview_win:set_buffer(new_buf)

    -- Clean up old preview buffer
    if self._preview_buf and self._preview_buf:is_valid() then
        pcall(function() self._preview_buf:close(true) end)
    end
    self._preview_buf = new_buf

    -- Try to enable treesitter highlighting for richer syntax colors
    if ft then
        pcall(vim.treesitter.start, new_buf:id(), ft)
    end

    -- Scroll to target line if specified
    if target_line and target_line > 0 then
        local line = math.min(target_line, #lines)
        pcall(vim.api.nvim_win_set_cursor, self._preview_win:id(), { line, 0 })
        -- Center the target line in the preview window
        vim.api.nvim_win_call(self._preview_win:id(), function()
            vim.cmd('normal! zz')
        end)
    else
        pcall(vim.api.nvim_win_set_cursor, self._preview_win:id(), { 1, 0 })
    end
end

--- Toggle preview pane visibility.
function SearchableList:_toggle_preview()
    if self._show_preview then
        -- Hide preview
        self._show_preview = false
        self:_close_preview()
        -- Resize the main list to fill the space
        self:_relayout()
    else
        -- Show preview
        self._show_preview = true
        self:_relayout()
        self:_update_preview()
    end
end

--- Recalculate and apply layout positions for list and preview windows.
function SearchableList:_relayout()
    if not self._mounted or not self._win or not self._win:is_valid() then return end

    local ew = Window.editor_width()
    local eh = Window.editor_height()
    local total_w = self._width <= 1 and math.floor(ew * self._width) or self._width
    local h = self._height <= 1 and math.floor(eh * self._height) or self._height

    local list_w, preview_w
    if self._show_preview then
        total_w = math.max(total_w, math.floor(ew * 0.85))
        list_w = math.floor(total_w * 0.4)
        preview_w = total_w - list_w - 1
    else
        list_w = total_w
        preview_w = 0
    end

    local row = math.floor((eh - h) / 2)
    local col = math.floor((ew - total_w) / 2)

    -- Resize shadow
    if self._shadow then self._shadow:close() end
    self._shadow = Shadow.for_float(row, col, total_w + 2, h + 2, 199)

    -- Resize list window
    self._win:update_config({
        relative = 'editor',
        row = row, col = col,
        width = list_w, height = h,
    })

    -- Create or close preview window
    if self._show_preview then
        if not self._preview_win or not self._preview_win:is_valid() then
            self:_create_preview_window(row, col + list_w + 2 + 1, preview_w, h)
        else
            self._preview_win:update_config({
                relative = 'editor',
                row = row, col = col + list_w + 2 + 1,
                width = preview_w, height = h,
            })
        end
    else
        self:_close_preview()
    end

    -- Re-focus the list
    self._win:focus()
    self:_render()
end

--- Function component for the full SearchableList view.
--- Renders search bar, separator, item rows, and status bar.
local function SearchableListView(props)
    local query = props.query or ''
    local items = props.items or {}
    local selected = props.selected or 1
    local scroll = props.scroll or 0
    local total = props.total or #items
    local height = props.height or 20
    local width = props.width or 60
    local visible = height - 3
    local item_rows = props.item_rows or {}

    local children = {}

    -- Row 1: search bar
    children[#children + 1] = {
        type = 'row', hl = 'IDEDialogFocused',
        children = {
            { type = 'text', text = '  ', hl = 'IDEDialogHotkey' },
            { type = 'text', text = query .. '▏', hl = 'IDEDialogFocused' },
        },
    }

    -- Row 2: separator
    children[#children + 1] = { type = 'separator', hl = 'IDEDialogBorder' }

    -- Item rows
    if #items == 0 then
        local msg = query ~= '' and 'No matches' or 'Type to search...'
        children[#children + 1] = { type = 'text', text = '   ' .. msg, hl = 'IDEDialogListDisabled' }
    else
        for idx, row_data in ipairs(item_rows) do
            local actual_idx = scroll + idx
            if actual_idx == selected then
                children[#children + 1] = {
                    type = 'row', hl = 'IDEDialogListSelected',
                    children = vim.list_extend(
                        { { type = 'text', text = '▸ ', hl = 'IDEDialogHotkey' } },
                        row_data
                    ),
                }
            else
                children[#children + 1] = {
                    type = 'row',
                    children = vim.list_extend(
                        { { type = 'text', text = '  ' } },
                        row_data
                    ),
                }
            end
        end
    end

    -- Pad remaining rows
    local used = 2 + #item_rows + (#items == 0 and 1 or 0)
    for _ = used + 1, height - 1 do
        children[#children + 1] = { type = 'text', text = '' }
    end

    -- Status bar (last row)
    local filtered_count = #items
    local status_text = filtered_count < total
        and string.format(' %d/%d of %d ', math.min(selected, filtered_count), filtered_count, total)
        or string.format(' %d/%d ', math.min(selected, filtered_count), total)
    local pad = math.max(0, width - #status_text)
    children[#children + 1] = {
        type = 'row', hl = 'IDEDialogBorder',
        children = {
            { type = 'text', text = string.rep(' ', pad), hl = 'IDEDialogBorder' },
            { type = 'text', text = status_text, hl = 'IDEDialogTitle' },
        },
    }

    return children
end

function SearchableList:_render()
    if not self._buf or not self._buf:is_valid() then return end
    local CC = require 'ide.toolkit.component'
    local w = self._win:width()
    local h = self._win:height()
    local visible = h - 3
    local items = self:items()

    -- Adjust scroll
    if self._selected > self._scroll + visible then
        self._scroll = self._selected - visible
    end
    if self._selected <= self._scroll then
        self._scroll = math.max(0, self._selected - 1)
    end

    -- Collect VNode rows from subclass render_item
    local item_rows = {}
    local visible_end = math.min(self._scroll + visible, #items)
    for i = self._scroll + 1, visible_end do
        item_rows[#item_rows + 1] = self:render_item(items[i], w)
    end

    local props = {
        query = self._query, items = items, selected = self._selected,
        scroll = self._scroll, total = self:total_count(),
        height = h, width = w, item_rows = item_rows,
    }

    if not self._sl_component then
        self._sl_component = CC.mount(SearchableListView, props, self._buf, self._win)
    else
        CC.update(self._sl_component, props)
    end

    self:_update_preview()
end

function SearchableList:_bind_keys()
    local sl = self

    for i = 32, 126 do
        local ch = string.char(i)
        if ch ~= '<' and ch ~= '>' then
            self._buf:bind_key('n', ch, function()
                sl._query = sl._query .. ch
                sl:on_query_change(sl._query)
                sl:_render()
            end)
        end
    end

    self._buf:bind_key('n', '<BS>', function()
        if #sl._query > 0 then
            local chars = vim.fn.split(sl._query, '\\zs')
            table.remove(chars)
            sl._query = table.concat(chars, '')
            sl:on_query_change(sl._query)
            sl:_render()
        end
    end)

    local function move(dir) sl:_move(dir) end
    self._buf:bind_key('n', '<Down>', function() move(1) end)
    self._buf:bind_key('n', '<C-n>', function() move(1) end)
    self._buf:bind_key('n', '<C-j>', function() move(1) end)
    self._buf:bind_key('n', '<Up>', function() move(-1) end)
    self._buf:bind_key('n', '<C-p>', function() move(-1) end)
    self._buf:bind_key('n', '<C-k>', function() move(-1) end)
    self._buf:bind_key('n', '<Tab>', function() move(1) end)
    self._buf:bind_key('n', '<S-Tab>', function() move(-1) end)
    self._buf:bind_key('n', '<CR>', function() sl:_submit() end)
    self._buf:bind_key('n', '<Esc>', function() sl:close() end)
    self._buf:bind_key('n', '<C-c>', function() sl:close() end)
    self._buf:bind_key('n', '<C-u>', function()
        sl._query = ''
        sl:on_query_change('')
        sl:_render()
    end)

    -- Toggle preview pane
    self._buf:bind_key('n', '<C-t>', function() sl:_toggle_preview() end)

    self._buf:bind_key('n', '<LeftMouse>', function()
        local mpos = IDE and IDE.mouse:position() or nil
        if not mpos then return end
        if mpos.winid == sl._win:id() then
            local row = mpos.line
            if row > 2 then
                local idx = sl._scroll + row - 2
                local items = sl:items()
                if idx >= 1 and idx <= #items then
                    sl._selected = idx
                    sl:_render()
                    sl:_submit()
                end
            end
        else
            sl:close()
        end
    end)
end

function SearchableList:_move(dir)
    local items = self:items()
    if #items == 0 then return end
    self._selected = self._selected + dir
    if self._selected < 1 then self._selected = #items end
    if self._selected > #items then self._selected = 1 end
    local visible = self._win:height() - 2
    if self._selected <= self._scroll then self._scroll = self._selected - 1
    elseif self._selected > self._scroll + visible then self._scroll = self._selected - visible end
    self:_render()
end

function SearchableList:_submit()
    local items = self:items()
    if self._selected > 0 and items[self._selected] then
        local item = items[self._selected]
        self:close()
        self:on_submit(item)
    end
end

function SearchableList:close()
    if not self._mounted then return end
    self._mounted = false
    if self._sl_component then
        local CC = require 'ide.toolkit.component'
        CC.unmount(self._sl_component)
        self._sl_component = nil
    end
    IDE.ui:restore_cursor()
    self:_close_preview()
    if self._shadow then self._shadow:close(); self._shadow = nil end
    if self._win and self._win:is_valid() then self._win:close(true) end
    if self._buf and self._buf:is_valid() then self._buf:close(true) end
    self._win = nil
    self._buf = nil
    if self._on_close_cb then self._on_close_cb() end
end

function SearchableList:is_visible() return self._mounted end

function SearchableList:__tostring()
    return string.format('SearchableList(%s)', self._title)
end

return SearchableList
