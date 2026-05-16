-- Terminal Extension: integrated terminal panel at the bottom of the IDE.
-- Togglable with Ctrl+` or from the View menu. Persists across buffer switches.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local Terminal = Class('Terminal', Extension)

function Terminal:init()
    Extension.init(self, 'Terminal')
    self._buf = nil  ---@type integer|nil
    self._win = nil  ---@type integer|nil
    self._height = 15
    self._visible = false
end

function Terminal:is_visible()
    return self._visible and self._win ~= nil and vim.api.nvim_win_is_valid(self._win)
end

function Terminal:toggle()
    if self:is_visible() then
        self:hide()
    else
        self:show()
    end
end

function Terminal:show()
    if self:is_visible() then return end

    -- Create terminal buffer if needed
    if not self._buf or not vim.api.nvim_buf_is_valid(self._buf) then
        self._buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_call(self._buf, function()
            vim.fn.jobstart(vim.o.shell, { term = true,
                cwd = IDE.fs:cwd(),
                on_exit = function()
                    vim.schedule(function() self:_on_exit() end)
                end,
            })
        end)
        vim.bo[self._buf].buflisted = false
        vim.bo[self._buf].filetype = 'ide-terminal'
    end

    -- Use a floating window at the bottom — window_chrome ignores floats
    local ew = Window.editor_width()
    local eh = Window.editor_height()
    local row = eh - self._height - 1

    self._win = vim.api.nvim_open_win(self._buf, true, {
        relative = 'editor',
        row = row,
        col = 0,
        width = ew,
        height = self._height,
        style = 'minimal',
        border = { '─', '─', '─', '', '', '', '', '' },
        zindex = 55,
    })

    -- Terminal window options
    local win = Window.get(self._win)
    if not win then return end
    win:set_option('number', false)
    win:set_option('relativenumber', false)
    win:set_option('signcolumn', 'no')
    win:set_option('winhl', 'Normal:IDETerminalNormal,FloatBorder:IDETerminalBorder')

    win:enter_insert()
    self._visible = true
    IDE:emit('terminal.show')
end

function Terminal:hide()
    if not self:is_visible() then return end
    pcall(vim.api.nvim_win_close, self._win, true)
    self._win = nil
    self._visible = false
    IDE:emit('terminal.hide')
end

function Terminal:_on_exit()
    self._buf = nil
    self:hide()
end

--- Send text to the terminal.
---@param text string
function Terminal:send(text)
    if not self._buf or not vim.api.nvim_buf_is_valid(self._buf) then return end
    local chan = vim.bo[self._buf].channel
    if chan and chan > 0 then
        vim.fn.chansend(chan, text .. '\n')
    end
end

--- Run a command in the terminal panel (shows panel if hidden).
---@param cmd string
function Terminal:run(cmd)
    self:show()
    vim.defer_fn(function() self:send(cmd) end, 100)
end

function Terminal:on_register(ctx)
    local ext = self

    -- Register actions
    ctx:action('terminal.toggle', 'Toggle terminal', function() ext:toggle() end)
    ctx:action('terminal.show', 'Show terminal', function() ext:show() end)
    ctx:action('terminal.hide', 'Hide terminal', function() ext:hide() end)

    -- Keymaps
    ctx:keymap('n', '<C-`>', 'terminal.toggle', { desc = 'Toggle terminal' })
    ctx:keymap('t', '<C-`>', function()
        Window.current():exit_insert()
        ext:hide()
    end, { desc = 'Hide terminal' })
    ctx:keymap('t', '<C-\\><C-n>', function()
        Window.current():exit_insert()
    end, { desc = 'Terminal normal mode' })

    -- Escape in terminal returns to editor
    ctx:keymap('t', '<Esc><Esc>', function()
        Window.current():exit_insert()
        ext:hide()
    end, { desc = 'Exit terminal' })

    -- Commands
    ctx:command('IDETerminal', function() ext:toggle() end, { desc = 'Toggle terminal' })
    ctx:command('IDETerminalRun', function(args)
        ext:run(args.args)
    end, { desc = 'Run in terminal', nargs = '*' })

    -- Highlights
    ctx:highlight('IDETerminalNormal', { bg = '#0f1125' })
    ctx:highlight('IDETerminalBorder', { fg = '#3b4261', bg = '#0f1125' })
    ctx:highlight('IDETerminalBar', { bg = '#1a1e3a', fg = '#7aa2f7', bold = true })
    ctx:highlight('IDETerminalBarDim', { bg = '#1a1e3a', fg = '#565f89' })

    -- Add to View menu
    if IDE.menu_bar then
        local MenuItem = require 'ide.toolkit.MenuItem'
        IDE.menu_bar:add_item('View', MenuItem({
            text = 'Terminal', icon = '', shortcut = 'Ctrl+`',
            action = function() ext:toggle() end,
        }))
    end

    -- Make IDE.terminal accessible
    IDE.terminal = ext
end

function Terminal:on_unregister()
    self:hide()
    if self._buf and vim.api.nvim_buf_is_valid(self._buf) then
        pcall(vim.api.nvim_buf_delete, self._buf, { force = true })
    end
    self._buf = nil
    IDE.terminal = nil
end

---@return string
function Terminal:__tostring()
    return string.format('Terminal(%s)', self._visible and 'visible' or 'hidden')
end

return Terminal
