-- QuickFix: beautiful floating quickfix replacement.
-- Replaces the built-in quickfix window with a rich floating panel
-- that shows diagnostics, search results, etc. with syntax highlighting.

local Panel = require 'ide.toolkit.Panel'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local QuickFixUI = Class('QuickFixUI', Panel)

function QuickFixUI:init(opts)
    opts = opts or {}
    Panel.init(self, {
        title = opts.title or ' Quick Fix',
        width = opts.width or 0.7,
        height = opts.height or 0.4,
        enter = true,
    })
    self._items = {}
    self._all_items = {}  -- unfiltered list (for filter restore)
    self._selected = 1
    self._on_jump = opts.on_jump
    self._preview_win = nil  ---@type Window|nil
    self._preview_buf = nil  ---@type Buffer|nil
    self._selections = {}    -- set of selected indices (1-based)
    self._filter_pattern = nil  ---@type string|nil
end

--- Load items from vim's quickfix list.
---@return QuickFixUI
function QuickFixUI:from_qflist()
    local qf = vim.fn.getqflist()
    self._items = {}
    for _, item in ipairs(qf) do
        local fname = ''
        if item.bufnr and item.bufnr > 0 then
            fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(item.bufnr), ':~:.')
        end
        self._items[#self._items + 1] = {
            filename = fname,
            lnum = item.lnum,
            col = item.col,
            text = vim.trim(item.text or ''),
            type = item.type or '',
            bufnr = item.bufnr,
            severity = item.type == 'E' and 'Error'
                or item.type == 'W' and 'Warn'
                or 'Info',
        }
    end
    self._all_items = vim.deepcopy(self._items)
    self._filter_pattern = nil
    self._selections = {}
    return self
end

--- Load items from diagnostics.
---@param bufnr integer|nil # nil for all buffers
---@return QuickFixUI
function QuickFixUI:from_diagnostics(bufnr)
    local diags = vim.diagnostic.get(bufnr)
    self._items = {}
    local sev_names = { 'Error', 'Warn', 'Info', 'Hint' }
    for _, d in ipairs(diags) do
        local fname = ''
        if d.bufnr and vim.api.nvim_buf_is_valid(d.bufnr) then
            fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(d.bufnr), ':~:.')
        end
        self._items[#self._items + 1] = {
            filename = fname,
            lnum = d.lnum + 1,
            col = d.col + 1,
            text = d.message,
            severity = sev_names[d.severity] or 'Info',
            bufnr = d.bufnr,
        }
    end
    self._all_items = vim.deepcopy(self._items)
    self._filter_pattern = nil
    self._selections = {}
    return self
end

function QuickFixUI:_on_mount()
    self:_render()

    -- Navigation
    self:map('n', 'j', function()
        self._selected = math.min(self._selected + 1, #self._items)
        vim.api.nvim_win_set_cursor(self:winid(), { self._selected, 0 })
        self:_preview()
    end)
    self:map('n', 'k', function()
        self._selected = math.max(self._selected - 1, 1)
        vim.api.nvim_win_set_cursor(self:winid(), { self._selected, 0 })
        self:_preview()
    end)

    -- Jump to item
    self:map('n', '<CR>', function()
        local item = self._items[self._selected]
        if item then
            self:hide()
            vim.schedule(function()
                self:_jump(item)
            end)
        end
    end)

    -- Open in split
    self:map('n', 's', function()
        local item = self._items[self._selected]
        if item then
            self:hide()
            vim.schedule(function()
                vim.cmd.split()
                self:_jump(item)
            end)
        end
    end)

    -- Open in vsplit
    self:map('n', 'v', function()
        local item = self._items[self._selected]
        if item then
            self:hide()
            vim.schedule(function()
                vim.cmd.vsplit()
                self:_jump(item)
            end)
        end
    end)

    -- Filter by pattern
    self:map('n', '/', function()
        self:_prompt_filter()
    end)

    -- Clear filter
    self:map('n', '<C-u>', function()
        self:_apply_filter(nil)
    end)

    -- History navigation
    self:map('n', '<', function()
        self:_history_older()
    end)
    self:map('n', '>', function()
        self:_history_newer()
    end)

    -- Multi-select
    self:map('n', '<Tab>', function()
        self:_toggle_selection()
    end)

    -- Batch delete selected (or current)
    self:map('n', 'dd', function()
        self:_delete_selected()
    end)

    -- Show initial preview
    if #self._items > 0 then
        self:_preview()
    end
end

function QuickFixUI:_jump(item)
    if item.bufnr and vim.api.nvim_buf_is_valid(item.bufnr) then
        vim.api.nvim_set_current_buf(item.bufnr)
    elseif item.filename and item.filename ~= '' then
        vim.cmd.edit(item.filename)
    end
    if item.lnum and item.lnum > 0 then
        pcall(vim.api.nvim_win_set_cursor, 0, { item.lnum, (item.col or 1) - 1 })
    end
    vim.cmd 'normal! zz'
    if self._on_jump then self._on_jump(item) end
end

--- Close the preview floating window if open.
function QuickFixUI:_close_preview()
    if self._preview_win and self._preview_win:is_valid() then
        self._preview_win:close(true)
    end
    if self._preview_buf and self._preview_buf:is_valid() then
        self._preview_buf:close(true)
    end
    self._preview_win = nil
    self._preview_buf = nil
end

--- Show a preview of the file at the selected quickfix item's location.
function QuickFixUI:_preview()
    self:_close_preview()

    local item = self._items[self._selected]
    if not item then return end

    -- Resolve the file path
    local filepath = nil
    if item.bufnr and item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr) then
        filepath = vim.api.nvim_buf_get_name(item.bufnr)
    elseif item.filename and item.filename ~= '' then
        filepath = vim.fn.fnamemodify(item.filename, ':p')
    end
    if not filepath or filepath == '' then return end

    -- Read file lines
    local lines = {}
    if item.bufnr and item.bufnr > 0 and vim.api.nvim_buf_is_loaded(item.bufnr) then
        lines = vim.api.nvim_buf_get_lines(item.bufnr, 0, -1, false)
    else
        local ok, content = pcall(vim.fn.readfile, filepath)
        if ok then lines = content end
    end
    if #lines == 0 then return end

    -- Determine preview window position (to the right of the quickfix panel)
    local qf_winid = self:winid()
    if not qf_winid then return end
    local qf_config = vim.api.nvim_win_get_config(qf_winid)
    local qf_w = qf_config.width or 60
    local qf_h = qf_config.height or 20
    local qf_row = qf_config.row
    local qf_col = qf_config.col

    -- Resolve row/col (may be table with val field in newer Neovim)
    local row_val = type(qf_row) == 'table' and (qf_row[false] or qf_row.val or 0) or (qf_row or 0)
    local col_val = type(qf_col) == 'table' and (qf_col[false] or qf_col.val or 0) or (qf_col or 0)

    local ew = Window.editor_width()
    local preview_w = math.min(60, ew - qf_w - col_val - 4)
    if preview_w < 20 then return end  -- not enough space for preview

    local preview_h = math.min(qf_h, 20)

    -- Create preview buffer
    self._preview_buf = Buffer.create({ listed = false, scratch = true })
    self._preview_buf:set_option('modifiable', true)
    self._preview_buf:set_lines(0, -1, lines)
    self._preview_buf:set_option('modifiable', false)
    self._preview_buf:set_option('bufhidden', 'wipe')

    -- Set filetype for syntax highlighting
    local ext = vim.fn.fnamemodify(filepath, ':e')
    if ext and ext ~= '' then
        local ft = vim.filetype.match({ filename = filepath, buf = self._preview_buf:id() })
        if ft then
            self._preview_buf:set_option('filetype', ft)
        end
    end

    -- Open preview float to the right of the quickfix panel
    self._preview_win = Window.open_float(self._preview_buf, {
        relative = 'editor',
        row = row_val,
        col = col_val + qf_w + 2,
        width = preview_w,
        height = preview_h,
        border = 'rounded',
        style = 'minimal',
        zindex = (self._zindex or 50) + 1,
        enter = false,
    })

    self._preview_win:set_option('winblend', self._winblend or 0)
    self._preview_win:set_option('cursorline', true)
    self._preview_win:set_option('number', true)
    self._preview_win:set_option('relativenumber', false)
    self._preview_win:set_option('signcolumn', 'no')
    self._preview_win:set_option('wrap', false)
    self._preview_win:set_option('winfixbuf', true)
    self._preview_win:set_option('winhighlight',
        'NormalFloat:IDEPanelNormal,FloatBorder:IDEPanelBorder,CursorLine:Visual')

    -- Scroll to the matching line
    local target_line = item.lnum or 1
    if target_line > 0 and target_line <= #lines then
        vim.api.nvim_win_set_cursor(self._preview_win:id(),
            { target_line, math.max(0, (item.col or 1) - 1) })
        -- Center the line in the preview window
        vim.api.nvim_win_call(self._preview_win:id(), function()
            vim.cmd('normal! zz')
        end)
    end

    -- Update title with filename
    local short_name = vim.fn.fnamemodify(filepath, ':t')
    vim.api.nvim_win_set_config(self._preview_win:id(), {
        relative = 'editor',
        row = row_val,
        col = col_val + qf_w + 2,
        width = preview_w,
        height = preview_h,
        title = ' ' .. short_name .. ' ',
        title_pos = 'center',
    })
end

function QuickFixUI:_render()
    local Canvas = require 'ide.toolkit.Canvas'
    local buf = self:buffer()
    if not buf or not buf:is_valid() then return end

    local sev_hl = {
        Error = 'DiagnosticError',
        Warn = 'DiagnosticWarn',
        Info = 'DiagnosticInfo',
        Hint = 'DiagnosticHint',
    }
    local sev_icon = {
        Error = ' ',
        Warn = ' ',
        Info = ' ',
        Hint = '󰌵 ',
    }

    local w = self._current_width or 80
    local h = math.max(#self._items, 1)
    local c = Canvas(w, h)

    if #self._items == 0 then
        local msg = self._filter_pattern
            and ('No items matching: ' .. self._filter_pattern)
            or 'No items'
        c:text(1, 3, msg, 'Comment')
    else
        for i, item in ipairs(self._items) do
            local hl = sev_hl[item.severity] or 'Normal'
            local col_pos = 1

            -- Selection marker
            if self._selections[i] then
                c:text(i, col_pos, '▌ ', 'WarningMsg')
                col_pos = col_pos + vim.api.nvim_strwidth('▌ ')
            else
                col_pos = col_pos + 0  -- no offset when not selected
            end

            -- Severity icon
            local icon = sev_icon[item.severity] or '  '
            c:text(i, col_pos, icon, hl)
            col_pos = col_pos + vim.api.nvim_strwidth(icon)

            -- File name (shortened)
            local fname = item.filename or ''
            if #fname > 40 then
                fname = '…' .. fname:sub(-39)
            end
            c:text(i, col_pos, fname, 'Directory')
            col_pos = col_pos + vim.api.nvim_strwidth(fname)

            -- Line:col
            if item.lnum and item.lnum > 0 then
                local loc = string.format(':%d', item.lnum)
                c:text(i, col_pos, loc, 'LineNr')
                col_pos = col_pos + #loc
                if item.col and item.col > 0 then
                    local col_str = string.format(':%d', item.col)
                    c:text(i, col_pos, col_str, 'Comment')
                    col_pos = col_pos + #col_str
                end
            end

            -- Separator
            c:text(i, col_pos, '  │ ', 'Comment')
            col_pos = col_pos + 4

            -- Message text
            local text = item.text:gsub('\n', ' ')
            local max_text = w - col_pos
            if #text > max_text then
                text = text:sub(1, max_text - 1) .. '…'
            end
            c:text(i, col_pos, text, hl)
        end
    end

    c:render(buf)

    -- Update title with filter and selection info
    self:_update_title()
end

--- Update the panel title to reflect filter and selection state.
function QuickFixUI:_update_title()
    local winid = self:winid()
    if not winid or not vim.api.nvim_win_is_valid(winid) then return end

    local parts = { ' Quick Fix' }
    local count = #self._items
    local total = #self._all_items

    if self._filter_pattern then
        parts[#parts + 1] = string.format(' [filter: %s — %d/%d]', self._filter_pattern, count, total)
    else
        parts[#parts + 1] = string.format(' [%d]', count)
    end

    local sel_count = vim.tbl_count(self._selections)
    if sel_count > 0 then
        parts[#parts + 1] = string.format(' (%d selected)', sel_count)
    end

    local title = table.concat(parts)
    local config = vim.api.nvim_win_get_config(winid)
    config.title = ' ' .. title .. ' '
    config.title_pos = 'center'
    vim.api.nvim_win_set_config(winid, config)
end

--- Override hide to also close the preview pane and reset state.
function QuickFixUI:hide()
    self:_close_preview()
    self._selections = {}
    self._filter_pattern = nil
    Panel.hide(self)
end

--- Apply a text filter to the items list.
---@param pattern string|nil # nil to clear filter
function QuickFixUI:_apply_filter(pattern)
    self._filter_pattern = pattern
    self._selections = {}
    if not pattern or pattern == '' then
        self._items = vim.deepcopy(self._all_items)
        self._filter_pattern = nil
    else
        local pat = pattern:lower()
        self._items = {}
        for _, item in ipairs(self._all_items) do
            local haystack = ((item.filename or '') .. ' ' .. (item.text or '')):lower()
            if haystack:find(pat, 1, true) then
                self._items[#self._items + 1] = item
            end
        end
    end
    self._selected = math.min(self._selected, math.max(#self._items, 1))
    self:_render()
    if #self._items > 0 then
        pcall(vim.api.nvim_win_set_cursor, self:winid(), { self._selected, 0 })
        self:_preview()
    else
        self:_close_preview()
    end
end

--- Prompt for a filter pattern.
function QuickFixUI:_prompt_filter()
    -- Temporarily restore cursor so vim.fn.input works
    if self._saved_guicursor then
        vim.o.guicursor = self._saved_guicursor
    end
    vim.schedule(function()
        local ok, pattern = pcall(vim.fn.input, {
            prompt = 'Filter: ',
            default = self._filter_pattern or '',
        })
        -- Re-hide cursor
        if not self._show_cursor then
            self._saved_guicursor = vim.o.guicursor
            vim.o.guicursor = 'a:IDEPanelHiddenCursor/IDEPanelHiddenCursor'
        end
        if ok and pattern ~= nil then
            self:_apply_filter(pattern)
        end
    end)
end

--- Toggle selection on the current item.
function QuickFixUI:_toggle_selection()
    if #self._items == 0 then return end
    if self._selections[self._selected] then
        self._selections[self._selected] = nil
    else
        self._selections[self._selected] = true
    end
    self:_render()
    -- Move down after toggling
    if self._selected < #self._items then
        self._selected = self._selected + 1
        pcall(vim.api.nvim_win_set_cursor, self:winid(), { self._selected, 0 })
        self:_preview()
    end
end

--- Delete selected items (or current item if none selected) from the quickfix list.
function QuickFixUI:_delete_selected()
    if #self._items == 0 then return end

    local to_delete = {}
    if vim.tbl_count(self._selections) > 0 then
        for idx, _ in pairs(self._selections) do
            to_delete[idx] = true
        end
    else
        to_delete[self._selected] = true
    end

    -- Build new items list (both _items and _all_items)
    local new_items = {}
    local deleted_items = {}
    for i, item in ipairs(self._items) do
        if to_delete[i] then
            deleted_items[item] = true
        else
            new_items[#new_items + 1] = item
        end
    end

    -- Also remove from _all_items
    local new_all = {}
    for _, item in ipairs(self._all_items) do
        if not deleted_items[item] then
            new_all[#new_all + 1] = item
        end
    end

    self._items = new_items
    self._all_items = new_all
    self._selections = {}
    self._selected = math.min(self._selected, math.max(#self._items, 1))

    -- Update the underlying vim quickfix list
    local qf_items = {}
    for _, item in ipairs(self._all_items) do
        qf_items[#qf_items + 1] = {
            bufnr = item.bufnr,
            lnum = item.lnum,
            col = item.col,
            text = item.text,
            type = item.type or '',
        }
    end
    vim.fn.setqflist({}, 'r', { items = qf_items })

    if #self._items == 0 then
        self:hide()
        return
    end

    self:_render()
    pcall(vim.api.nvim_win_set_cursor, self:winid(), { self._selected, 0 })
    self:_preview()
end

--- Navigate to an older quickfix list.
function QuickFixUI:_history_older()
    local ok = pcall(vim.cmd, 'colder')
    if ok then
        self:from_qflist()
        self._selections = {}
        self._filter_pattern = nil
        self._selected = 1
        self:_render()
        pcall(vim.api.nvim_win_set_cursor, self:winid(), { self._selected, 0 })
        self:_preview()
    end
end

--- Navigate to a newer quickfix list.
function QuickFixUI:_history_newer()
    local ok = pcall(vim.cmd, 'cnewer')
    if ok then
        self:from_qflist()
        self._selections = {}
        self._filter_pattern = nil
        self._selected = 1
        self:_render()
        pcall(vim.api.nvim_win_set_cursor, self:winid(), { self._selected, 0 })
        self:_preview()
    end
end

--- Show count in title.
---@return string
function QuickFixUI:__tostring()
    return string.format('QuickFixUI(%d items, %s)',
        #self._items,
        self:is_visible() and 'visible' or 'hidden')
end

return QuickFixUI
