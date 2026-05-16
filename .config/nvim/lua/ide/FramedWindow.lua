-- FramedWindow: TurboVision MDI child window.
-- A floating window with double-line borders on all 4 sides,
-- title bar with close/maximize buttons, and footer with line:col.
-- Hosts a real buffer with full editor features (line numbers, signs, folds).
--
-- This is the proper OOP abstraction for bordered editor windows.
-- Instead of hacking borders via statuscolumn/winbar/statusline,
-- the float's native `border`, `title`, and `footer` provide all 4 sides.

local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local EventEmitter = require 'ide.EventEmitter'
local Shadow = require 'ide.toolkit.Shadow'

local FramedWindow = Class('FramedWindow')
Class.include(FramedWindow, EventEmitter)

-- Title bar click dispatchers (consolidated via Dispatch module).
local Dispatch = require 'ide.Dispatch'
Dispatch.ensure_vim_functions()

Dispatch.click('frame_close', function(_)
    vim.schedule(function()
        if IDE and IDE._window_chrome then
            IDE._window_chrome:close_current()
        end
    end)
end)

Dispatch.click('frame_maximize', function(_)
    vim.schedule(function()
        if IDE and IDE._window_chrome then
            IDE._window_chrome:toggle_maximize_current()
        end
    end)
end)

-- Global aliases needed by VimScript wrapper functions
_G.IDE_frame_close_lua = function(...) Dispatch.get_click('frame_close')(...) end
_G.IDE_frame_maximize_lua = function(...) Dispatch.get_click('frame_maximize')(...) end

---@class FramedWindowOpts
---@field buf Buffer|integer # buffer to display
---@field row? integer # position (0-indexed from editor top)
---@field col? integer # position (0-indexed from editor left)
---@field width? integer # content width (excluding borders)
---@field height? integer # content height (excluding borders)
---@field number? integer # window number for title bar

---@param opts FramedWindowOpts
function FramedWindow:init(opts)
    local buf_id = type(opts.buf) == 'number' and opts.buf or opts.buf:id()
    self._buf_id = buf_id
    self._row = opts.row or 0
    self._col = opts.col or 0
    self._width = opts.width or (vim.o.columns - 2)
    self._height = opts.height or (vim.o.lines - 4)
    self._number = opts.number or 1
    self._win_id = nil
    self._maximized = false
    self._saved_layout = nil
    self._shadow = nil
    self._shadow_enabled = opts.shadow ~= false
    self._draggable = opts.draggable or false
    self._resizable = opts.resizable or false
    self._drag_state = nil
end

--- Build the title as a single string with ═ padding to position
--- [■] flush-left and [↕] flush-right within the border line.
---@return table[]
function FramedWindow:_build_title()
    local buf = Buffer(self._buf_id)
    local name = buf:is_valid() and (buf:name() or '[No Name]') or '[Invalid]'
    local modified = (buf:is_valid() and buf:is_modified()) and ' +' or ''

    local icon = ''
    if IDE and IDE.icons and IDE.icons:is_loaded() then
        local path = buf:is_valid() and buf:path() or nil
        if path then
            local fname = vim.fn.fnamemodify(path, ':t')
            local ext = vim.fn.fnamemodify(path, ':e')
            local ic = IDE.icons:for_file(fname, ext)
            if ic then icon = ic:char() .. ' ' end
        end
    end

    local center = string.format(' [%d] %s%s%s ', self._number, icon, name, modified)
    local center_w = vim.api.nvim_strwidth(center)
    local close_w = 3  -- [■]
    local max_w = 3    -- [↕]
    local total_border = self._width - close_w - max_w - center_w
    local left_pad = math.max(1, math.floor(total_border / 2))
    local right_pad = math.max(1, total_border - left_pad)

    return {
        { '[■]', 'IDEWinButton' },
        { string.rep('═', left_pad), 'IDEWinBorder' },
        { center, 'IDEWinTitle' },
        { string.rep('═', right_pad), 'IDEWinBorder' },
        { '[↕]', 'IDEWinButton' },
    }
end

--- Build the footer components.
---@return table[]
function FramedWindow:_build_footer()
    if not self._win_id or not vim.api.nvim_win_is_valid(self._win_id) then
        return { { ' 1:1 ', 'IDEWinPos' } }
    end
    local cursor = vim.api.nvim_win_get_cursor(self._win_id)
    local line = cursor[1]
    local col = cursor[2] + 1
    local pos = string.format(' %d:%d ', line, col)

    -- Breadcrumb from treesitter scope chain
    local scope = ''
    local buf = Buffer.get(self._buf_id)
    if buf:is_valid() and buf:is_normal() then
        local ok, crumb = pcall(function() return buf:ast():breadcrumb() end)
        if ok and crumb and crumb ~= '' then
            local max_w = self._width - vim.api.nvim_strwidth(pos) - 4
            if #crumb > max_w then
                crumb = '…' .. crumb:sub(-max_w + 1)
            end
            scope = ' ' .. crumb .. ' '
        end
    end

    if scope ~= '' then
        return {
            { scope, 'IDEWinbarScope' },
            { pos, 'IDEWinPos' },
        }
    end
    return { { pos, 'IDEWinPos' } }
end

--- Show the framed window.
function FramedWindow:show()
    if self._win_id and vim.api.nvim_win_is_valid(self._win_id) then return end

    -- Shadow behind the window
    if self._shadow_enabled then
        self._shadow = Shadow.for_float(self._row, self._col, self._width + 2, self._height + 2, 49)
    end

    -- Resizable windows get a resize grip in the bottom-right corner
    local border = { '╔', '═', '╗', '║', '╝', '═', '╚', '║' }
    if self._resizable then
        border[5] = '◢'  -- bottom-right resize grip
    end

    local float_config = {
        relative = 'editor',
        row = self._row,
        col = self._col,
        width = self._width,
        height = self._height,
        border = border,
        title = self:_build_title(),
        title_pos = 'left',
        footer = self:_build_footer(),
        footer_pos = 'right',
        style = 'minimal',
        zindex = 50,
    }

    self._win_id = vim.api.nvim_open_win(self._buf_id, true, float_config)

    -- Enable full editor features inside the float
    local w = self._win_id
    vim.wo[w].number = true
    vim.wo[w].relativenumber = true
    vim.wo[w].signcolumn = 'yes:1'
    vim.wo[w].cursorline = true
    vim.wo[w].foldcolumn = '1'
    vim.wo[w].foldenable = true
    vim.wo[w].foldmethod = 'expr'
    vim.wo[w].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    vim.wo[w].foldlevel = 99
    vim.wo[w].wrap = false
    vim.wo[w].winblend = 0
    vim.wo[w].winhighlight = table.concat({
        'Normal:Normal',
        'NormalNC:Normal',
        'FloatBorder:IDEWinBorder',
        'FloatTitle:IDEWinTitle',
        'FloatFooter:IDEWinPos',
        'SignColumn:IDEFrameGutter',
        'FoldColumn:IDEFrameGutter',
        'CursorLineSign:IDEFrameGutter',
        'CursorLineFold:IDEFrameGutter',
        'LineNr:IDEFrameLineNr',
        'CursorLineNr:IDEFrameCurLineNr',
        'EndOfBuffer:Normal',
    }, ',')

    -- Apply statuscolumn if available
    local stc = vim.o.statuscolumn
    if stc and stc ~= '' then
        vim.wo[w].statuscolumn = stc
    end

    -- Trigger FileType to ensure LSP attaches to the buffer in this float
    local ft = vim.bo[self._buf_id].filetype
    if ft and ft ~= '' then
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(self._buf_id) then
                vim.api.nvim_exec_autocmds('FileType', { buffer = self._buf_id, modeline = false })
            end
        end)
    end

    self:emit('show')
end

--- Update the title and footer (call after cursor move, buffer change, etc.).
--- Only calls nvim_win_set_config when the title/footer actually changed to reduce flicker.
function FramedWindow:refresh()
    if not self._win_id or not vim.api.nvim_win_is_valid(self._win_id) then return end
    self._buf_id = vim.api.nvim_win_get_buf(self._win_id)

    if not vim.wo[self._win_id].number then
        vim.wo[self._win_id].number = true
        vim.wo[self._win_id].relativenumber = true
    end

    local new_title = self:_build_title()
    local new_footer = self:_build_footer()

    -- Build a cache key from title/footer text content
    local title_key = ''
    for _, part in ipairs(new_title) do title_key = title_key .. part[1] end
    local footer_key = ''
    for _, part in ipairs(new_footer) do footer_key = footer_key .. part[1] end
    local cache_key = title_key .. '|' .. footer_key

    if cache_key ~= self._last_chrome_key then
        self._last_chrome_key = cache_key
        pcall(vim.api.nvim_win_set_config, self._win_id, {
            title = new_title,
            title_pos = 'left',
            footer = new_footer,
            footer_pos = 'right',
        })
    end

    self:_render_scrollbar()
end

--- Render a scrollbar as a 1-column floating window pinned to the right edge.
--- This approach works for ALL lines including empty area below buffer content.
function FramedWindow:_render_scrollbar()
    if not self._win_id or not vim.api.nvim_win_is_valid(self._win_id) then return end
    if not vim.api.nvim_buf_is_valid(self._buf_id) then return end

    local win_height = vim.api.nvim_win_get_height(self._win_id)
    local line_count = vim.api.nvim_buf_line_count(self._buf_id)
    if win_height <= 2 then return end

    -- Get visible range
    local top = vim.fn.line('w0', self._win_id)
    local bot = vim.fn.line('w$', self._win_id)
    if top <= 0 then top = 1 end
    if bot <= 0 then bot = math.min(line_count, win_height) end

    -- Calculate thumb
    local track_height = win_height
    local thumb_size, thumb_pos
    if line_count <= win_height then
        thumb_size = track_height - 2
        thumb_pos = 1
    else
        thumb_size = math.max(1, math.floor(track_height * win_height / line_count))
        thumb_pos = 1 + math.floor((track_height - 2 - thumb_size) * (top - 1) / math.max(1, line_count - win_height))
    end

    -- Build scrollbar lines
    local lines = {}
    local hls = {}
    for i = 0, track_height - 1 do
        if i == 0 then
            lines[#lines + 1] = '▲'
            hls[#hls + 1] = 'IDEScrollButton'
        elseif i == track_height - 1 then
            lines[#lines + 1] = '▼'
            hls[#hls + 1] = 'IDEScrollButton'
        elseif i >= thumb_pos and i < thumb_pos + thumb_size then
            lines[#lines + 1] = '▓'
            hls[#hls + 1] = 'IDEScrollThumb'
        else
            lines[#lines + 1] = '░'
            hls[#hls + 1] = 'IDEScrollTrack'
        end
    end

    -- Create or update the scrollbar float
    if not self._sb_buf or not vim.api.nvim_buf_is_valid(self._sb_buf) then
        self._sb_buf = vim.api.nvim_create_buf(false, true)
        vim.bo[self._sb_buf].bufhidden = 'wipe'
        vim.bo[self._sb_buf].buftype = 'nofile'
        vim.bo[self._sb_buf].buflisted = false
    end

    vim.bo[self._sb_buf].modifiable = true
    vim.api.nvim_buf_set_lines(self._sb_buf, 0, -1, false, lines)
    vim.bo[self._sb_buf].modifiable = false

    -- Apply highlights
    self._sb_ns = self._sb_ns or vim.api.nvim_create_namespace('ide_scrollbar')
    local ns = self._sb_ns
    vim.api.nvim_buf_clear_namespace(self._sb_buf, ns, 0, -1)
    for i, hl in ipairs(hls) do
        vim.api.nvim_buf_add_highlight(self._sb_buf, ns, hl, i - 1, 0, -1)
    end

    -- Position: right edge of content area, inside the border
    local sb_row = self._row + 1  -- +1 for top border
    local sb_col = self._col + self._width  -- last content column (before right border)

    -- Clean up own stale scrollbar only (don't touch sibling frames' scrollbars)
    if self._sb_win and not vim.api.nvim_win_is_valid(self._sb_win) then
        self._sb_win = nil
    end
    if not self._sb_win then
        self._sb_win = vim.api.nvim_open_win(self._sb_buf, false, {
            relative = 'editor',
            row = sb_row,
            col = sb_col,
            width = 1,
            height = win_height,
            style = 'minimal',
            focusable = false,
            zindex = 51,
        })
        vim.wo[self._sb_win].winblend = 0
        vim.wo[self._sb_win].winhighlight = 'Normal:IDEScrollTrack'
    else
        pcall(vim.api.nvim_win_set_config, self._sb_win, {
            relative = 'editor',
            row = sb_row,
            col = sb_col,
            width = 1,
            height = win_height,
        })
        vim.api.nvim_win_set_buf(self._sb_win, self._sb_buf)
    end
end

--- Resize and reposition the framed window.
---@param row integer
---@param col integer
---@param width integer
---@param height integer
function FramedWindow:set_layout(row, col, width, height)
    self._row = row
    self._col = col
    self._width = width
    self._height = height
    if self._win_id and vim.api.nvim_win_is_valid(self._win_id) then
        vim.api.nvim_win_set_config(self._win_id, {
            relative = 'editor',
            row = row,
            col = col,
            width = width,
            height = height,
        })
    end
    -- Move shadow to match
    if self._shadow then
        self._shadow:close()
        self._shadow = Shadow.for_float(row, col, width + 2, height + 2, 49)
    end
end

--- Fill the available editor area (below tabline, above cmdline).
function FramedWindow:fill()
    local area = Window.content_area()
    local row = area.row
    local col = area.col
    local width = area.width
    local height = area.height
    self:set_layout(row, col, width, height)
end

--- Set the buffer displayed in this window.
---@param buf Buffer|integer
function FramedWindow:set_buffer(buf)
    local id = type(buf) == 'number' and buf or buf:id()
    self._buf_id = id
    if self._win_id and vim.api.nvim_win_is_valid(self._win_id) then
        vim.api.nvim_win_set_buf(self._win_id, id)
        vim.wo[self._win_id].number = true
        vim.wo[self._win_id].relativenumber = true
        self:refresh()
    end
end

--- Get the buffer ID.
---@return integer
function FramedWindow:buffer_id()
    return self._buf_id
end

--- Get the window ID.
---@return integer|nil
function FramedWindow:window_id()
    return self._win_id
end

--- Check if this framed window is visible and valid.
---@return boolean
function FramedWindow:is_valid()
    return self._win_id ~= nil and vim.api.nvim_win_is_valid(self._win_id)
end

--- Set the window number shown in the title bar.
---@param n integer
function FramedWindow:set_number(n)
    self._number = n
    self:refresh()
end

--- Start dragging the window from a mouse position.
---@param mouse_row integer
---@param mouse_col integer
function FramedWindow:start_drag(mouse_row, mouse_col)
    self._drag_state = {
        offset_row = mouse_row - self._row,
        offset_col = mouse_col - self._col,
    }
end

--- Continue dragging to a new mouse position.
---@param mouse_row integer
---@param mouse_col integer
function FramedWindow:drag_to(mouse_row, mouse_col)
    if not self._drag_state then return end
    local new_row = mouse_row - self._drag_state.offset_row
    local new_col = mouse_col - self._drag_state.offset_col
    -- Clamp to editor bounds
    new_row = math.max(1, math.min(new_row, vim.o.lines - self._height - 3))
    new_col = math.max(0, math.min(new_col, vim.o.columns - self._width - 2))
    self:set_layout(new_row, new_col, self._width, self._height)
end

--- Stop dragging.
function FramedWindow:stop_drag()
    self._drag_state = nil
end

--- Check if a mouse position is on the title bar.
---@param mouse_row integer # 0-indexed screen row
---@param mouse_col integer # 0-indexed screen col
---@return boolean
function FramedWindow:is_on_title_bar(mouse_row, mouse_col)
    return mouse_row == self._row
        and mouse_col >= self._col
        and mouse_col < self._col + self._width + 2
end

--- Check if a mouse position is on the resize grip (bottom-right corner).
---@param mouse_row integer
---@param mouse_col integer
---@return boolean
function FramedWindow:is_on_resize_grip(mouse_row, mouse_col)
    if not self._resizable then return false end
    return mouse_row == self._row + self._height + 1
        and mouse_col == self._col + self._width + 1
end

--- Close the framed window.
function FramedWindow:close()
    if self._shadow then self._shadow:close(); self._shadow = nil end
    if self._sb_win and vim.api.nvim_win_is_valid(self._sb_win) then
        vim.api.nvim_win_close(self._sb_win, true)
    end
    self._sb_win = nil
    self._sb_buf = nil
    if self._win_id and vim.api.nvim_win_is_valid(self._win_id) then
        vim.api.nvim_win_close(self._win_id, true)
    end
    self._win_id = nil
    self._drag_state = nil
    self:emit('close')
    self:clear()
end

function FramedWindow:__tostring()
    local buf = vim.api.nvim_buf_is_valid(self._buf_id)
        and (vim.api.nvim_buf_get_name(self._buf_id):match('[^/]+$') or '[No Name]')
        or '[Invalid]'
    return string.format('FramedWindow(%d, %s, %s)',
        self._number, buf, self:is_valid() and 'open' or 'closed')
end

return FramedWindow
