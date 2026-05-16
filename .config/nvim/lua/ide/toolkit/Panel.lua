-- Panel: base floating/split window component.
-- All other UI components (List, QuickFix, TreeView, FuzzyPicker) extend this.
-- Provides consistent borders, theming, keymaps, positioning, and lifecycle.

local EventEmitter = require 'ide.EventEmitter'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Shadow = require 'ide.toolkit.Shadow'

local Panel = Class('Panel')
Class.include(Panel, EventEmitter)

Panel.DEFAULTS = {
    border = 'rounded',
    width = 0.6,
    height = 0.5,
    zindex = 50,
    opacity = 0.95,
}

---@class PanelOpts
---@field title? string
---@field width? number           -- absolute or fraction (0-1 = percentage of editor)
---@field height? number          -- absolute or fraction
---@field border? string|table
---@field enter? boolean          -- focus on show (default true)
---@field position? string|table  -- 'center'|'bottom'|'top'|'left'|'right'|'cursor'|{row,col}
---@field zindex? integer
---@field opacity? number         -- 0-1
---@field auto_dismiss? boolean   -- close on WinLeave (default false)
---@field dismiss_keys? string[]  -- keys that close the panel (default {'q', '<Esc>'})
---@field buf? Buffer             -- use an existing buffer

---@param opts PanelOpts|nil
function Panel:init(opts)
    opts = opts or {}
    self._title = opts.title or ''
    self._mounted = false
    self._buf = nil ---@type Buffer|nil
    self._win = nil ---@type Window|nil
    self._external_buf = opts.buf
    self._position = opts.position or 'center'
    self._auto_dismiss = opts.auto_dismiss ~= false  -- default true
    self._dismiss_keys = opts.dismiss_keys or { 'q', '<Esc>' }
    self._enter = opts.enter ~= false
    self._border = opts.border or Panel.DEFAULTS.border
    self._zindex = opts.zindex or Panel.DEFAULTS.zindex
    self._winblend = math.floor((1 - (opts.opacity or Panel.DEFAULTS.opacity)) * 100)
    self._shadow_enabled = opts.shadow ~= false
    self._shadow = nil
    self._show_cursor = opts.show_cursor or false

    local w = opts.width or Panel.DEFAULTS.width
    local h = opts.height or Panel.DEFAULTS.height
    self._width_spec = w
    self._height_spec = h
end

--- Resolve width/height from specs (fractions or absolutes).
---@return integer, integer
function Panel:_resolve_size()
    local ew = Window.editor_width()
    local eh = Window.editor_height()
    local w = self._width_spec
    local h = self._height_spec
    if type(w) == 'number' and w <= 1 then w = math.floor(ew * w) end
    if type(h) == 'number' and h <= 1 then h = math.floor(eh * h) end
    return math.max(1, math.floor(w)), math.max(1, math.floor(h))
end

--- Resolve row/col from position spec.
---@param w integer
---@param h integer
---@return integer, integer
function Panel:_resolve_position(w, h)
    local ew = Window.editor_width()
    local eh = Window.editor_height()
    local pos = self._position

    if type(pos) == 'table' then
        return pos.row or 0, pos.col or 0
    elseif pos == 'center' then
        return math.floor((eh - h) / 2), math.floor((ew - w) / 2)
    elseif pos == 'top' then
        return 0, math.floor((ew - w) / 2)
    elseif pos == 'bottom' then
        return eh - h - 2, math.floor((ew - w) / 2)
    elseif pos == 'left' then
        return math.floor((eh - h) / 2), 0
    elseif pos == 'right' then
        return math.floor((eh - h) / 2), ew - w - 2
    elseif pos == 'cursor' then
        return 1, 0  -- relative to cursor, set relative='cursor' in config
    end
    return math.floor((eh - h) / 2), math.floor((ew - w) / 2)
end

---@return Panel
function Panel:show()
    if self._mounted then return self end

    -- Save the window to restore on hide
    self._prev_win = vim.api.nvim_get_current_win()

    if self._external_buf then
        self._buf = self._external_buf
    else
        self._buf = Buffer.create({ listed = false, scratch = true })
        self._buf:set_option('modifiable', false)
        self._buf:set_option('bufhidden', 'wipe')
        self._buf:set_option('filetype', 'ide-panel')
    end

    local w, h = self:_resolve_size()
    local row, col = self:_resolve_position(w, h)

    local float_config = {
        relative = self._position == 'cursor' and 'cursor' or 'editor',
        row = row,
        col = col,
        width = w,
        height = h,
        border = self._border,
        style = 'minimal',
        zindex = self._zindex,
        enter = self._enter,
    }

    if self._title ~= '' then
        float_config.title = ' ' .. self._title .. ' '
        float_config.title_pos = 'center'
    end

    -- Shadow behind the panel
    if self._shadow_enabled and self._position ~= 'cursor' then
        self._shadow = Shadow.for_float(row, col, w + 2, h + 2, self._zindex - 1)
    end

    self._win = Window.open_float(self._buf, float_config)
    self._mounted = true
    self._current_width = w
    self._current_height = h

    self._win:set_option('winblend', self._winblend)
    self._win:set_option('cursorline', false)
    self._win:set_option('winfixbuf', true)
    self._win:set_option('number', false)
    self._win:set_option('relativenumber', false)
    self._win:set_option('signcolumn', 'no')
    self._win:set_option('wrap', false)
    self._win:set_option('winhighlight',
        'NormalFloat:IDEPanelNormal,FloatBorder:IDEPanelBorder,FloatTitle:IDEPanelTitle'
        .. ',CursorLine:IDEPanelNormal,Cursor:IDEPanelHiddenCursor')

    for _, key in ipairs(self._dismiss_keys) do
        self:map('n', key, function() self:hide() end)
    end

    -- Mouse click: select clicked line or close if outside
    local panel = self
    self:map('n', '<LeftMouse>', function()
        local mpos = vim.fn.getmousepos()
        if not mpos then return end
        if panel._win and panel._win:is_valid() and mpos.winid == panel._win:id() then
            if mpos.line > 0 then
                pcall(vim.api.nvim_win_set_cursor, panel._win:id(), { mpos.line, 0 })
                panel:emit('click', mpos.line)
            end
        else
            panel:hide()
        end
    end)

    -- Hide cursor in panel windows (non-editable UI)
    if not self._show_cursor then
        IDE.ui:hide_cursor()
    end

    self:emit('show')
    self:_on_mount()

    if self._auto_dismiss then
        self:_setup_auto_dismiss()
    end

    return self
end

function Panel:_setup_auto_dismiss()
    local panel = self
    local panel_winid = self._win and self._win:id()
    local bufnr = self._buf and self._buf:id()
    if not bufnr or not panel_winid then return end
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    vim.defer_fn(function()
        if not panel._mounted or not panel._buf then return end
        if not vim.api.nvim_buf_is_valid(panel._buf:id()) then return end
        vim.api.nvim_create_autocmd('WinLeave', {
            buffer = panel._buf:id(),
            once = true,
            callback = function()
                vim.schedule(function()
                    if not panel._mounted then return end
                    local cur = vim.api.nvim_get_current_win()
                    if cur ~= panel_winid then panel:hide() end
                end)
            end,
        })
    end, 100)
end

function Panel:hide()
    if not self._mounted then return end
    self:emit('hide')

    -- Restore cursor visibility
    if not self._show_cursor then
        IDE.ui:restore_cursor()
    end

    if self._shadow then self._shadow:close(); self._shadow = nil end
    if self._win and self._win:is_valid() then
        self._win:close(true)
    end
    if not self._external_buf and self._buf and self._buf:is_valid() then
        self._buf:close(true)
    end

    self._mounted = false
    self._win = nil
    self._buf = nil

    -- Restore focus to previous window
    if self._prev_win and vim.api.nvim_win_is_valid(self._prev_win) then
        pcall(vim.api.nvim_set_current_win, self._prev_win)
    end
    self._prev_win = nil
end

function Panel:toggle()
    if self._mounted then self:hide() else self:show() end
end

--- Update layout without remounting.
---@param opts { width?: number, height?: number, position?: string|table }|nil
function Panel:update_layout(opts)
    if not self._mounted or not self._win or not self._win:is_valid() then return end
    opts = opts or {}
    if opts.width then self._width_spec = opts.width end
    if opts.height then self._height_spec = opts.height end
    if opts.position then self._position = opts.position end

    local w, h = self:_resolve_size()
    local row, col = self:_resolve_position(w, h)
    self._win:update_config({
        relative = self._position == 'cursor' and 'cursor' or 'editor',
        width = w, height = h, row = row, col = col,
    })
    self._current_width = w
    self._current_height = h
end

---@return integer|nil
function Panel:bufnr()
    return self._buf and self._buf:id() or nil
end

---@return Buffer|nil
function Panel:buffer()
    return self._buf
end

---@return integer|nil
function Panel:winid()
    return self._win and self._win:id() or nil
end

---@return Window|nil
function Panel:window()
    return self._win
end

---@return integer, integer
function Panel:size()
    return self._current_width or 0, self._current_height or 0
end

---@param lines string[]
function Panel:set_lines(lines)
    if not self._buf then return end
    self._buf:set_option('modifiable', true)
    self._buf:set_lines(0, -1, lines)
    self._buf:set_option('modifiable', false)
end

--- Set styled lines for rich rendering.
---@param styled_lines table[] # StyledLine objects
function Panel:set_styled_lines(styled_lines)
    if not self._buf then return end
    local bufnr = self._buf:id()
    self._buf:set_option('modifiable', true)
    self._buf:set_lines(0, -1, vim.tbl_map(function() return '' end, styled_lines))
    for i, line in ipairs(styled_lines) do
        line:render(bufnr, -1, i)
    end
    self._buf:set_option('modifiable', false)
end

-- Legacy alias
Panel.set_nui_lines = Panel.set_styled_lines

---@param mode string
---@param key string
---@param fn function
function Panel:map(mode, key, fn)
    if self._buf and self._buf:is_valid() then
        self._buf:bind_key(mode, key, fn)
    end
end

function Panel:_on_mount() end

---@return boolean
function Panel:is_visible()
    return self._mounted
end

---@return string
function Panel:__tostring()
    return string.format('Panel(%s, %s)', self._title, self._mounted and 'visible' or 'hidden')
end

return Panel
