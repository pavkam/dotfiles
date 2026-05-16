-- Window: OOP abstraction over neovim windows.
-- Wraps vim.api.nvim_win_* with reactive events and buffer linking.
--
-- Events: 'enter', 'leave', 'resize', 'close'

local EventEmitter = require 'ide.EventEmitter'
local Position = require 'ide.Position'

local Window = Class('Window')
Class.include(Window, EventEmitter)

local _cache = {}

---@param id integer
function Window:init(id)
    assert(type(id) == 'number' and vim.api.nvim_win_is_valid(id), 'invalid window id')
    self._id = id
end

--- Get a cached Window instance (identity-stable).
---@param id integer
---@return Window
function Window.get(id)
    if not vim.api.nvim_win_is_valid(id) then
        _cache[id] = nil
        return Window(id)
    end
    local cached = _cache[id]
    if cached then return cached end
    local win = Window(id)
    _cache[id] = win
    return win
end

---@return integer
function Window:id()
    return self._id
end

--- Check validity. Works as instance method (win:is_valid()) or static (Window.is_valid(id)).
---@return boolean
function Window:is_valid()
    local id = type(self) == 'number' and self or self._id
    return vim.api.nvim_win_is_valid(id)
end

--- Get the buffer displayed in this window.
---@return Buffer
function Window:buffer()
    local Buffer = require 'ide.Buffer'
    return Buffer.get(vim.api.nvim_win_get_buf(self._id))
end

--- Set the buffer displayed in this window.
---@param buf table # Buffer instance or buffer id
function Window:set_buffer(buf)
    local id = type(buf) == 'number' and buf or buf:id()
    vim.api.nvim_win_set_buf(self._id, id)
end

--- Get cursor position.
---@return Position
function Window:cursor()
    return Position.from_cursor(vim.api.nvim_win_get_cursor(self._id))
end

--- Set cursor position.
---@param pos Position|{row: integer, col: integer}
function Window:set_cursor(pos)
    if pos.to_cursor then
        vim.api.nvim_win_set_cursor(self._id, pos:to_cursor())
    else
        vim.api.nvim_win_set_cursor(self._id, { pos.row, pos.col - 1 })
    end
end

---@return integer
function Window:width()
    return vim.api.nvim_win_get_width(self._id)
end

---@return integer
function Window:height()
    return vim.api.nvim_win_get_height(self._id)
end

--- Get the visible line range (1-indexed).
---@return integer, integer # top line, bottom line
function Window:visible_range()
    return vim.fn.line('w0', self._id), vim.fn.line('w$', self._id)
end

--- Check if this is a floating window.
---@return boolean
function Window:is_floating()
    local config = vim.api.nvim_win_get_config(self._id)
    return config.relative and config.relative ~= ''
end

--- Whether the window is pinned to its buffer.
---@return boolean
function Window:is_pinned()
    return vim.wo[self._id].winfixbuf
end

---@param value boolean
function Window:set_pinned(value)
    vim.wo[self._id].winfixbuf = value
end

--- Execute a function in this window's context.
---@param fn function
---@return any
function Window:call(fn)
    return vim.api.nvim_win_call(self._id, fn)
end

--- Get a window option by name.
---@param name string
---@return any
function Window:option(name)
    return vim.wo[self._id][name]
end

--- Set a window option by name.
---@param name string
---@param value any
function Window:set_option(name, value)
    vim.wo[self._id][name] = value
end

--- Update floating window configuration.
---@param config table
function Window:update_config(config)
    if self:is_valid() then
        vim.api.nvim_win_set_config(self._id, config)
    end
end

--- Make this window the active window.
function Window:focus()
    if self:is_valid() then
        vim.api.nvim_set_current_win(self._id)
    end
end

--- Close this window.
---@param force boolean|nil
function Window:close(force)
    if self:is_valid() then
        self:emit('close')
        vim.api.nvim_win_close(self._id, force or false)
    end
end

--- Get the status column (gutter) width in characters.
---@return integer
function Window:status_column_width()
    return vim.fn.getwininfo(self._id)[1].textoff
end

--- Check if a line is folded.
---@param line integer|nil # 1-indexed (default: cursor line)
---@return boolean|nil # true=closed, false=foldable but open, nil=no fold
function Window:is_folded(line)
    line = line or self:cursor().row
    return self:call(function()
        if vim.fn.foldclosed(line) >= 0 then
            return true
        end
        local ok, expr = pcall(vim.treesitter.foldexpr, line)
        if ok and tostring(expr):sub(1, 1) == '>' then
            return false
        end
        return nil
    end)
end

--- Toggle fold at a line.
---@param line integer|nil # 1-indexed (default: cursor line)
---@return boolean|nil # true=opened, false=closed, nil=no fold
function Window:toggle_fold(line)
    line = line or self:cursor().row
    return self:call(function()
        if vim.fn.foldclosed(line) == line then
            vim.cmd.foldopen { range = { line } }
            return true
        elseif vim.fn.foldlevel(line) > 0 then
            vim.cmd.foldclose { range = { line } }
            return false
        end
        return nil
    end)
end

--- Run a function with the cursor temporarily at a specific line.
---@param fn function
---@param line integer # 1-indexed
function Window:invoke_on_line(fn, line)
    local saved = self:cursor()
    local ok, err = pcall(function()
        self:set_cursor(require('ide.Position')(line, 1))
        self:call(fn)
    end)
    self:set_cursor(saved)
    if not ok then error(err, 2) end
end

--- Get the currently selected text in visual mode.
---@return string
function Window:selected_text()
    if not vim.tbl_contains({ 'v', 'V', '\22' }, vim.fn.mode()) then
        return ''
    end
    return self:call(function()
        local old_content = vim.fn.getreg('a')
        local old_type = vim.fn.getregtype('a')
        vim.cmd([[silent! normal! "aygv]])
        local sel = vim.fn.getreg('a')
        vim.fn.setreg('a', old_content, old_type)
        return sel
    end)
end

--- Execute normal mode keys in this window.
---@param keys string
function Window:exec_normal(keys)
    self:call(function() vim.cmd('normal! ' .. keys) end)
end

--- Get the fold range at a line (1-indexed).
---@param line integer # 1-indexed line number
---@return integer|nil, integer|nil # fold start, fold end (1-indexed) or nil if no fold
function Window:fold_range(line)
    return self:call(function()
        local start = vim.fn.foldclosed(line)
        local finish = vim.fn.foldclosedend(line)
        if start == -1 then return nil, nil end
        return start, finish
    end)
end

--- Open a floating window.
---@param buf Buffer|integer
---@param config table # nvim_open_win config (relative, row, col, width, height, border, etc.)
---@return Window
function Window.open_float(buf, config)
    local buf_id = type(buf) == 'number' and buf or buf:id()
    local enter = config.enter
    config.enter = nil
    local id = vim.api.nvim_open_win(buf_id, enter or false, config)
    return Window(id)
end

--- Get the editor's total columns.
---@return integer
function Window.editor_width()
    return vim.o.columns
end

--- Get the editor's total lines.
---@return integer
function Window.editor_height()
    return vim.o.lines
end

--- Get the usable content area for MDI windows (below tabline, above statusline/cmdline).
--- Accounts for tabline (1), global statusline (1 if laststatus=3), cmdline (1).
---@return { row: integer, col: integer, width: integer, height: integer }
function Window.content_area()
    local has_tabline = vim.o.showtabline > 0
    local has_global_stl = vim.o.laststatus == 3
    local cmdheight = vim.o.cmdheight

    local top = has_tabline and 1 or 0
    local bottom = (has_global_stl and 1 or 0) + math.max(cmdheight, 1)
    local width = vim.o.columns - 2   -- minus float border left+right
    local height = vim.o.lines - top - bottom - 2  -- minus float border top+bottom

    return { row = top, col = 0, width = width, height = height }
end

--- Start a visual selection between two positions.
---@param start_pos Position
---@param end_pos Position
function Window:select_range(start_pos, end_pos)
    self:set_cursor(start_pos)
    vim.cmd('normal! v')
    self:set_cursor(end_pos)
end

--- Split this window.
---@param direction 'vertical'|'horizontal'|nil
---@return Window
function Window:split(direction)
    local cmd = direction == 'horizontal' and 'split' or 'vsplit'
    self:call(function()
        vim.cmd(cmd)
    end)
    return Window.current()
end

--- Get the floating window configuration.
---@return table
function Window:config()
    return vim.api.nvim_win_get_config(self._id)
end

---@return string
function Window:__tostring()
    local buf = self:is_valid() and self:buffer() or nil
    return string.format('Window(%d, %s)', self._id, buf and buf:name() or '?')
end

-- Class methods

---@return Window
function Window.current()
    return Window.get(vim.api.nvim_get_current_win())
end

---@return Window[]
function Window.list()
    local result = {}
    for _, id in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(id) then
            table.insert(result, Window.get(id))
        end
    end
    return result
end

--- Get all windows displaying a specific buffer.
---@param bufnr integer
---@return Window[]
function Window.for_buffer(bufnr)
    local result = {}
    for _, id in ipairs(vim.fn.win_findbuf(bufnr)) do
        if vim.api.nvim_win_is_valid(id) then
            result[#result + 1] = Window.get(id)
        end
    end
    return result
end

--- Cycle to the next window.
function Window.cycle()
    vim.cmd('wincmd w')
end

--- Cycle to the previous window.
function Window.cycle_reverse()
    vim.cmd('wincmd W')
end

--- Equalize all window sizes.
function Window.equalize()
    vim.cmd('wincmd =')
end

--- Close all windows except the current one.
function Window.close_others()
    vim.cmd('only')
end

-- ── Reactive event helpers ──────────────────────────────────────

--- Subscribe to a window-scoped event.
---@param event string # 'enter', 'leave', 'resize', 'close'
---@param fn function
---@return integer
function Window:on_event(event, fn)
    local map = {
        enter  = 'WinEnter',
        leave  = 'WinLeave',
        resize = 'WinResized',
        close  = 'WinClosed',
    }
    local autocmd = map[event]
    if not autocmd then error('Unknown window event: ' .. event) end

    local win = self
    local id = vim.api.nvim_create_autocmd(autocmd, {
        callback = function(ev)
            local target = event == 'close' and tonumber(ev.match) or vim.api.nvim_get_current_win()
            if target == win._id then
                fn(win, ev)
                if event == 'close' then
                    win:_cleanup_autocmds()
                end
            end
        end,
    })
    self._autocmd_ids = self._autocmd_ids or {}
    self._autocmd_ids[#self._autocmd_ids + 1] = id
    return id
end

function Window:_cleanup_autocmds()
    if self._autocmd_ids then
        for _, id in ipairs(self._autocmd_ids) do
            pcall(vim.api.nvim_del_autocmd, id)
        end
        self._autocmd_ids = {}
    end
end

function Window:on_enter(fn) return self:on_event('enter', fn) end
function Window:on_leave(fn) return self:on_event('leave', fn) end
function Window:on_resize(fn) return self:on_event('resize', fn) end

return Window
