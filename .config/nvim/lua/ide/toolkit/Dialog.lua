-- Dialog: TurboVision-style modal dialog with double-line borders,
-- title bar, shadow effect, and child widget layout.
-- All child widgets support &hotkey notation for keyboard accelerators.

local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Shadow = require 'ide.toolkit.Shadow'

local Dialog = Class('Dialog')

---@class DialogOpts
---@field title string
---@field width? integer
---@field height? integer
---@field on_close? fun()
---@field shadow? boolean

---@param opts DialogOpts
function Dialog:init(opts)
    self._title = opts.title or 'Dialog'
    self._width = opts.width or 40
    self._height = opts.height or 10
    self._on_close = opts.on_close
    self._use_shadow = opts.shadow ~= false
    self._buf = nil ---@type Buffer|nil
    self._win = nil ---@type Window|nil
    self._shadow = nil ---@type Shadow|nil
    self._mounted = false
    self._widgets = {} ---@type table[]
    self._hotkeys = {} ---@type table<string, function>
    self._focus_index = 0
    self._focusable = {} ---@type table[]
end

--- Add a widget to the dialog at a specific row.
---@param widget table # Widget instance (Checkbox, RadioGroup, Button, etc.)
---@param row integer # 1-indexed row within dialog content area
---@param col? integer # 1-indexed column (default 1)
function Dialog:add_widget(widget, row, col)
    self._widgets[#self._widgets + 1] = {
        widget = widget,
        row = row,
        col = col or 1,
    }
    if widget.focusable and widget:focusable() then
        self._focusable[#self._focusable + 1] = widget
    end
end

--- Parse &hotkey from label text.
---@param text string
---@return string, string|nil # display text, hotkey char
local function parse_hotkey(text)
    local pos = text:find('&')
    if not pos then return text, nil end
    local display = text:sub(1, pos - 1) .. text:sub(pos + 1)
    local hotkey = text:sub(pos + 1, pos + 1):lower()
    return display, hotkey
end

--- Register a hotkey action.
---@param key string # single lowercase letter
---@param action function
function Dialog:register_hotkey(key, action)
    self._hotkeys[key:lower()] = action
end

function Dialog:show()
    if self._mounted then return end

    local ew = Window.editor_width()
    local eh = Window.editor_height()

    local width = math.min(self._width, ew - 4)
    local height = math.min(self._height, eh - 4)
    local row = math.floor((eh - height) / 2)
    local col = math.floor((ew - width) / 2)

    -- Shadow (rendered behind the dialog)
    if self._use_shadow then
        self._shadow = Shadow.for_float(row, col, width + 2, height + 2, 199)
    end

    -- Main dialog window
    self._buf = Buffer.create({ listed = false, scratch = true })
    self._buf:set_option('bufhidden', 'wipe')
    self._buf:set_option('filetype', 'ide-dialog')

    -- Double-line box-drawing border with title
    local title_display = parse_hotkey(self._title)
    local border = {
        { '╔', 'IDEDialogBorder' },
        { '═', 'IDEDialogBorder' },
        { '╗', 'IDEDialogBorder' },
        { '║', 'IDEDialogBorder' },
        { '╝', 'IDEDialogBorder' },
        { '═', 'IDEDialogBorder' },
        { '╚', 'IDEDialogBorder' },
        { '║', 'IDEDialogBorder' },
    }

    self._win = Window.open_float(self._buf, {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        border = border,
        title = {
            { '[■]', 'IDEWinButton' },
            { '═', 'IDEDialogBorder' },
            { ' ' .. title_display .. ' ', 'IDEDialogTitle' },
        },
        title_pos = 'left',
        style = 'minimal',
        zindex = 200,
        enter = true,
    })
    self._mounted = true

    self._win:set_option('cursorline', false)
    self._win:set_option('wrap', false)
    self._win:set_option('winhl', 'Normal:IDEDialogNormal,FloatBorder:IDEDialogBorder')
    self._win:set_option('winblend', 0)

    local ok, err = pcall(function()
        self:_render_content()
        self:_bind_keys()
        self:_register_hotkeys()

        -- Focus first focusable widget
        if #self._focusable > 0 then
            self._focus_index = 1
            self._focusable[1]:on_focus()
        end
    end)
    if not ok then
        pcall(function() self:hide() end)
        vim.schedule(function()
            vim.notify('[IDE] Dialog error: ' .. tostring(err), vim.log.levels.ERROR)
        end)
    end
end

function Dialog:_render_content()
    if not self._buf or not self._buf:is_valid() then return end

    local Canvas = require 'ide.toolkit.Canvas'
    local c = Canvas(self._width, self._height)

    for _, entry in ipairs(self._widgets) do
        local w = entry.widget
        local row = entry.row
        local col_pos = entry.col
        local text, highlights = w:render()
        if text and row <= self._height then
            c:text(row, col_pos, text)
            if highlights then
                for _, hl in ipairs(highlights) do
                    c._highlights[#c._highlights + 1] = {
                        row = row,
                        col_start = hl.col_start + col_pos - 1,
                        col_end = hl.col_end + col_pos - 1,
                        group = hl.group,
                    }
                end
            end
        end
    end

    c:render(self._buf)
end

function Dialog:_bind_keys()
    local dlg = self
    local bufnr = self._buf:id()

    local function map(key, fn)
        self._buf:bind_key('n', key, fn)
    end

    map('<Esc>', function() dlg:close() end)
    map('q', function() dlg:close() end)

    -- Tab cycles focus between widgets
    map('<Tab>', function() dlg:_cycle_focus(1) end)
    map('<S-Tab>', function() dlg:_cycle_focus(-1) end)

    -- Enter/Space activate the focused widget
    map('<CR>', function()
        if dlg._focus_index > 0 and dlg._focusable[dlg._focus_index] then
            dlg._focusable[dlg._focus_index]:on_activate()
            dlg:_render_content()
        end
    end)
    map('<Space>', function()
        if dlg._focus_index > 0 and dlg._focusable[dlg._focus_index] then
            dlg._focusable[dlg._focus_index]:on_activate()
            dlg:_render_content()
        end
    end)

    -- j/k navigate within focused ListBox/RadioGroup
    map('j', function()
        local w = dlg._focusable[dlg._focus_index]
        if w and w.move then w:move(1); dlg:_render_content()
        elseif w and w.navigate then w:navigate(1); dlg:_render_content()
        end
    end)
    map('k', function()
        local w = dlg._focusable[dlg._focus_index]
        if w and w.move then w:move(-1); dlg:_render_content()
        elseif w and w.navigate then w:navigate(-1); dlg:_render_content()
        end
    end)

    -- Mouse click: detect which widget was clicked by row
    map('<LeftMouse>', function()
        local mpos = vim.fn.getmousepos()
        if not mpos or not dlg._win or not dlg._win:is_valid() then return end
        if mpos.winid ~= dlg._win:id() then
            dlg:close()
            return
        end
        local row = mpos.line
        for _, entry in ipairs(dlg._widgets) do
            if entry.row == row then
                local w = entry.widget
                if w.on_activate then
                    w:on_activate()
                    dlg:_render_content()
                end
                if w.focusable and w:focusable() then
                    -- Update focus to clicked widget
                    for fi, fw in ipairs(dlg._focusable) do
                        if fw == w then
                            if dlg._focus_index > 0 and dlg._focusable[dlg._focus_index] then
                                dlg._focusable[dlg._focus_index]:on_blur()
                            end
                            dlg._focus_index = fi
                            w:on_focus()
                            dlg:_render_content()
                            break
                        end
                    end
                end
                return
            end
        end
    end)

    -- Auto-close when focus leaves
    vim.api.nvim_create_autocmd('WinLeave', {
        buffer = bufnr,
        once = true,
        callback = function()
            vim.schedule(function()
                if dlg._mounted then dlg:close() end
            end)
        end,
    })
end

function Dialog:_register_hotkeys()
    if not self._buf or not self._buf:is_valid() then return end
    local bufnr = self._buf:id()
    local dlg = self

    -- Scan widgets for & hotkeys
    for _, entry in ipairs(self._widgets) do
        local w = entry.widget
        if w.label then
            local _, hotkey = parse_hotkey(w:label())
            if hotkey then
                self._hotkeys[hotkey] = function()
                    if w.on_activate then
                        w:on_activate()
                        dlg:_render_content()
                    end
                    if w.on_focus then w:on_focus() end
                end
            end
        end
    end

    -- Register all hotkeys as buffer-local keymaps
    for key, action in pairs(self._hotkeys) do
        self._buf:bind_key('n', key, action)
        self._buf:bind_key('n', string.upper(key), action)
    end
end

function Dialog:_cycle_focus(dir)
    if #self._focusable == 0 then return end

    -- Blur current
    if self._focus_index > 0 and self._focusable[self._focus_index] then
        self._focusable[self._focus_index]:on_blur()
    end

    -- Move
    self._focus_index = self._focus_index + dir
    if self._focus_index > #self._focusable then self._focus_index = 1 end
    if self._focus_index < 1 then self._focus_index = #self._focusable end

    -- Focus new
    self._focusable[self._focus_index]:on_focus()
    self:_render_content()
end

function Dialog:close()
    if not self._mounted then return end
    self._mounted = false

    if self._win and self._win:is_valid() then
        self._win:close(true)
    end
    if self._buf and self._buf:is_valid() then
        self._buf:close(true)
    end
    if self._shadow then
        self._shadow:close()
        self._shadow = nil
    end

    self._win = nil
    self._buf = nil

    if self._on_close then
        vim.schedule(self._on_close)
    end
end

function Dialog:is_visible()
    return self._mounted and self._win ~= nil and self._win:is_valid()
end

function Dialog:buffer()
    return self._buf
end

function Dialog:window()
    return self._win
end

function Dialog:__tostring()
    return string.format('Dialog(%s, %dx%d, %s)',
        self._title, self._width, self._height,
        self._mounted and 'open' or 'closed')
end

return Dialog
