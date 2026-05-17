-- IDE: The master singleton that provides access to all neovim abstractions.
-- Every vim concept is wrapped in an object. Plugins are internalized as
-- features of these objects, not standalone components.
--
-- Usage:
--   local ide = require('ide')  -- returns the singleton
--
--   -- Buffers
--   ide.buffers:current():format()
--   ide.buffers:current():on('save', function() print('saved!') end)
--
--   -- Windows
--   ide.windows:current():split('vertical')
--
--   -- LSP
--   ide.lsp:add('gopls', { settings = { gopls = { gofumpt = true } } })
--   ide.lsp:get('gopls'):on('attach', function(client, buf) ... end)
--
--   -- Project
--   ide.project:root()
--   ide.project:type() -- 'go', 'python', 'typescript', etc.
--
--   -- Keys
--   ide.keys:map('n', '<leader>f', ':Telescope find_files<cr>', { desc = 'Find files' })
--
--   -- File system
--   ide.fs:exists('/path/to/file')
--
--   -- Shell
--   ide.shell:run('git', {'status'}, nil, function(r) print(r.stdout) end)

local EventEmitter = require 'ide.EventEmitter'
local BufferList = require 'ide.BufferList'
local WindowList = require 'ide.WindowList'
local FileSystem = require 'ide.FileSystem'
local Shell = require 'ide.Shell'
local LspManager = require 'ide.LspManager'
local Project = require 'ide.Project'
local KeyManager = require 'ide.KeyManager'
local UI = require 'ide.UI'
local ConfigManager = require 'ide.ConfigManager'
local ThemeManager = require 'ide.ThemeManager'
local SessionManager = require 'ide.SessionManager'
local DebugManager = require 'ide.DebugManager'
local Treesitter = require 'ide.Treesitter'
local Git = require 'ide.Git'
local QuickFix = require 'ide.QuickFix'
local Marks = require 'ide.Marks'
local Command = require 'ide.Command'
local Timer = require 'ide.Timer'
local Mouse = require 'ide.Mouse'
local Text = require 'ide.Text'
local ActionRegistry = require 'ide.ActionRegistry'
local IconDB = require 'ide.IconDB'
local FormatterRunner = require 'ide.FormatterRunner'
local LinterRunner = require 'ide.LinterRunner'
local ProgressTracker = require 'ide.ProgressTracker'

---@class IDE
---@field buffers BufferList
---@field windows WindowList
---@field fs FileSystem
---@field shell Shell
---@field lsp LspManager
---@field keys KeyManager
---@field ui UI
---@field config ConfigManager
---@field theme ThemeManager
---@field session SessionManager
---@field debug DebugManager
---@field treesitter Treesitter
---@field git Git
---@field quickfix QuickFix
---@field marks Marks
---@field formatter FormatterRunner
---@field linter LinterRunner
---@field progress ProgressTracker
---@field mouse Mouse
---@field commands { add: fun(self, name: string, fn: function, opts?: table): Command, remove: fun(self, name: string), list: fun(self): string[] }
---@field statusbar StatusBar|nil
---@field tabbar TabBar|nil
---@field winbar WinBar|nil
---@field menu_bar MenuBar|nil
---@field on fun(self, event: string, fn: function) EventEmitter mixin
---@field off fun(self, event: string, fn: function) EventEmitter mixin
---@field emit fun(self, event: string, ...: any) EventEmitter mixin
local IDE = Class('IDE')
Class.include(IDE, EventEmitter)

function IDE:init()
    local function safe_init(name, constructor)
        local ok, result = pcall(constructor)
        if not ok then
            vim.schedule(function()
                vim.api.nvim_echo({{ string.format('IDE: %s failed: %s', name, tostring(result)), 'ErrorMsg' }}, true, {})
            end)
            return nil
        end
        return result
    end

    self.buffers = safe_init('BufferList', BufferList) or {}
    self.windows = safe_init('WindowList', WindowList) or {}
    self.fs = safe_init('FileSystem', FileSystem)
    self.shell = safe_init('Shell', Shell)
    self.lsp = safe_init('LspManager', LspManager)
    self.keys = safe_init('KeyManager', KeyManager)
    self.ui = safe_init('UI', UI)
    self.config = safe_init('ConfigManager', ConfigManager)
    self.theme = safe_init('ThemeManager', ThemeManager)
    self.session = safe_init('SessionManager', SessionManager)
    self.debug = safe_init('DebugManager', DebugManager)
    self.treesitter = safe_init('Treesitter', Treesitter)
    self.git = safe_init('Git', function() return Git(self.shell) end)
    self.quickfix = safe_init('QuickFix', QuickFix)
    self.marks = safe_init('Marks', Marks)
    self.formatter = safe_init('FormatterRunner', FormatterRunner)
    self.linter = safe_init('LinterRunner', LinterRunner)
    self.progress = safe_init('ProgressTracker', ProgressTracker)
    self.commands = self:_create_command_registry()
    self.mouse = safe_init('Mouse', Mouse)
    self.text = Text()
    self.actions = ActionRegistry()
    self.icons = IconDB()

    -- Extension registry
    self._extensions = {} ---@type table<string, Extension>

    -- Bars
    self.statusbar = nil ---@type StatusBar|nil
    self.tabbar = nil ---@type TabBar|nil
    self.winbar = nil ---@type WinBar|nil
    self.menu_bar = nil ---@type MenuBar|nil

    -- Project detection (lazy — detected on first access or buffer open)
    self._project = nil

    -- Set global before wiring events (subsystems reference _G.IDE)
    _G.IDE = self

    -- Register formatter and linter tool definitions
    local tool_defs = require 'ide.tools'
    tool_defs.register_formatters(self.formatter)
    tool_defs.register_linters(self.linter)

    self:_wire_events()
    self.mouse:_wire_events()

    -- Register extensions (deferred to avoid startup ordering issues)
    vim.schedule(function()
        self:_register_core_actions()
        self:_register_extensions()
        self.config:load()
        self.keys:enable_auto_hints()
        self:emit('ready')
    end)

end

--- Safely require and register an extension.
---@param mod string
function IDE:_safe_register(mod)
    local ok, ext_or_err = pcall(require, mod)
    if not ok then
        vim.schedule(function()
            IDE.ui:error(string.format('Extension "%s" failed to require: %s', mod, tostring(ext_or_err)))
        end)
        return
    end
    local ok2, inst_or_err = pcall(ext_or_err)
    if not ok2 then
        vim.schedule(function()
            IDE.ui:error(string.format('Extension "%s" failed to instantiate: %s', mod, tostring(inst_or_err)))
        end)
        return
    end
    self:register_extension(inst_or_err)
end

--- Register all built-in extensions.
function IDE:_register_extensions()
    self:_safe_register('ide.extensions.message_filter')
    self:_safe_register('ide.extensions.notifications')
    self:_safe_register('ide.extensions.statusline')
    self:_safe_register('ide.extensions.status_column')
    self:_safe_register('ide.extensions.main_menu')
    self:_safe_register('ide.extensions.autotag')
    self:_safe_register('ide.extensions.icon_picker')
    self:_safe_register('ide.extensions.markdown_preview')
    self:_safe_register('ide.extensions.ts_comments')
    self:_safe_register('ide.extensions.ts_error_translator')
    self:_safe_register('ide.extensions.indent_guides')
    self:_safe_register('ide.extensions.jump')
    self:_safe_register('ide.extensions.folding')
    self:_safe_register('ide.extensions.git_signs')
    self:_safe_register('ide.extensions.context_menus')
    self:_safe_register('ide.extensions.panels')
    self:_safe_register('ide.extensions.diagnostics_panel')
    self:_safe_register('ide.extensions.buffer_picker')
    self:_safe_register('ide.extensions.test_runner')
    self:_safe_register('ide.extensions.feature_toggles')
    self:_safe_register('ide.extensions.ui_select')
    self:_safe_register('ide.extensions.file_operations')
    self:_safe_register('ide.extensions.editor_defaults')
    self:_safe_register('ide.extensions.buffer_keymaps')
    self:_safe_register('ide.extensions.editing_keymaps')
    self:_safe_register('ide.extensions.cursor_effects')
    self:_safe_register('ide.extensions.file_safety')
    self:_safe_register('ide.extensions.search_keymaps')
    self:_safe_register('ide.extensions.snippets')
    self:_safe_register('ide.extensions.debug_keymaps')
    self:_safe_register('ide.extensions.notes')
    self:_safe_register('ide.extensions.spelling')
    self:_safe_register('ide.extensions.mark_signs')
    self:_safe_register('ide.extensions.file_palette')
    self:_safe_register('ide.extensions.tmux_integration')
    self:_safe_register('ide.extensions.session_persistence')
    self:_safe_register('ide.extensions.quickfix_keymaps')
    self:_safe_register('ide.extensions.lsp_keymaps')
    self:_safe_register('ide.extensions.lazygit')
    self:_safe_register('ide.extensions.shell_commands')
    self:_safe_register('ide.extensions.command_palette')
    self:_safe_register('ide.extensions.format_on_save')
    self:_safe_register('ide.extensions.lint_on_change')
    self:_safe_register('ide.extensions.treesitter_textobjects')
    self:_safe_register('ide.extensions.completion')
    self:_safe_register('ide.extensions.find_replace')
    self:_safe_register('ide.extensions.terminal')
    self:_safe_register('ide.extensions.outline')
    self:_safe_register('ide.extensions.desktop')
    self:_safe_register('ide.extensions.window_chrome')
    self:_safe_register('ide.extensions.turbovision_theme')
end

--- Register an extension with the IDE.
---@param ext Extension
---@return IDE
function IDE:register_extension(ext)
    if self._extensions[ext:name()] then
        self:unregister_extension(ext:name())
    end
    self._extensions[ext:name()] = ext
    local start = vim.uv.hrtime()
    local ok, err = pcall(function() ext:_enable() end)
    local elapsed = (vim.uv.hrtime() - start) / 1e6
    ext._load_time_ms = elapsed
    if not ok then
        ext._error = tostring(err)
        vim.schedule(function()
            IDE.ui:error(string.format('Extension "%s" failed to load: %s', ext:name(), tostring(err)))
        end)
    end
    self:emit('extension.register', ext)
    return self
end

--- Unregister an extension.
---@param name string
---@return IDE
function IDE:unregister_extension(name)
    local ext = self._extensions[name]
    if ext then
        ext:_disable()
        self._extensions[name] = nil
        self:emit('extension.unregister', name)
    end
    return self
end

--- Get a registered extension.
---@param name string
---@return Extension|nil
function IDE:extension(name)
    return self._extensions[name]
end

--- List all registered extensions.
---@return Extension[]
function IDE:extensions()
    local result = {}
    for _, ext in pairs(self._extensions) do
        result[#result + 1] = ext
    end
    return result
end

--- Register context action providers from each subsystem.
--- Each provider is decoupled — it only contributes items when its
--- conditions are met (LSP attached, diagnostics present, git hunk, etc.)
-- Context providers moved to extensions: git_signs.lua, context_menus.lua

--- The current project (detected from the current buffer).
---@return Project|nil
function IDE:project()
    if not self._project then
        self._project = Project.detect()
    end
    return self._project
end

--- Create the command registry instance.
---@return table
function IDE:_create_command_registry()
    local registry = {}
    registry._commands = {} ---@type table<string, Command>

    function registry:add(name, fn, opts)
        local cmd = Command.create(name, fn, opts)
        self._commands[name] = cmd
        return cmd
    end

    function registry:remove(name)
        local cmd = self._commands[name]
        if cmd then
            cmd:delete()
            self._commands[name] = nil
        end
    end

    function registry:execute(name, opts)
        local cmd = self._commands[name]
        if cmd and cmd._action then
            cmd._action(opts or {})
        else
            vim.cmd { cmd = name, args = opts and opts.args or {} }
        end
    end

    function registry:list()
        return vim.tbl_keys(self._commands)
    end

    return registry
end

--- Wire all autocommand-based events.
function IDE:_wire_events()
    self.buffers:_wire_events()
    self.windows:_wire_events()
    self.lsp:_wire_events()
    self.theme:_wire_events()

    -- Bubble buffer events to IDE level
    self.buffers:on('open', function(buf)
        self:emit('buffer.open', buf)
        -- Re-detect project when opening files from different roots
        self._project = nil
    end)
    self.buffers:on('close', function(buf)
        self:emit('buffer.close', buf)
    end)
    self.buffers:on('change', function(buf)
        self:emit('buffer.change', buf)
    end)

    -- Bubble window events
    self.windows:on('enter', function(win)
        self:emit('window.enter', win)
    end)
    self.windows:on('close', function(win)
        self:emit('window.close', win)
    end)

    -- Bubble LSP events
    self.lsp:on('attach', function(client, bufnr)
        self:emit('lsp.attach', client, bufnr)
    end)
    self.lsp:on('detach', function(client, bufnr)
        self:emit('lsp.detach', client, bufnr)
    end)
end

-- ── IDE-level commands ─────────────────────────────────────────
-- High-level actions that extensions call instead of raw vim.cmd.

function IDE:save_all()
    pcall(vim.cmd, 'wall')
end

function IDE:quit(force)
    vim.cmd(force and 'qall!' or 'confirm qall')
end

function IDE:help(topic)
    local ok, err = pcall(vim.cmd, 'help' .. (topic and (' ' .. topic) or ''))
    if not ok then
        self.ui:error('Help failed: ' .. tostring(err))
        return
    end
    -- The help window is a split — close it and show the buffer in our frame
    if self._window_chrome and self._window_chrome._frame and self._window_chrome._frame:is_valid() then
        local help_buf = vim.api.nvim_get_current_buf()
        if vim.bo[help_buf].buftype == 'help' then
            local help_win = vim.api.nvim_get_current_win()
            local frame_win = self._window_chrome._frame:window_id()
            if help_win ~= frame_win then
                self._window_chrome._frame:set_buffer(help_buf)
                vim.api.nvim_set_current_win(frame_win)
                pcall(vim.api.nvim_win_close, help_win, true)
            end
        end
    end
end

function IDE:healthcheck()
    local ok, err = pcall(vim.cmd, 'checkhealth')
    if not ok then
        self.ui:error('Health check failed: ' .. tostring(err))
        return
    end
    if self._window_chrome and self._window_chrome._frame and self._window_chrome._frame:is_valid() then
        local buf = vim.api.nvim_get_current_buf()
        local win = vim.api.nvim_get_current_win()
        local frame_win = self._window_chrome._frame:window_id()
        if win ~= frame_win then
            self._window_chrome._frame:set_buffer(buf)
            vim.api.nvim_set_current_win(frame_win)
            pcall(vim.api.nvim_win_close, win, true)
        end
    end
end

--- Register core IDE actions in the action registry.
--- All buffer/window actions receive ctx { buf: Buffer, win: Window }.
function IDE:_register_core_actions()
    self.actions:register('editor.save', { desc = 'Save buffer', fn = function(ctx)
        if ctx.buf:is_valid() then ctx.buf:save() end
    end })
    self.actions:register('editor.saveAll', { desc = 'Save all buffers', fn = function() self:save_all() end })
    self.actions:register('editor.undo', { desc = 'Undo', fn = function(ctx) ctx.buf:undo() end })
    self.actions:register('editor.redo', { desc = 'Redo', fn = function(ctx) ctx.buf:redo() end })
    self.actions:register('editor.format', { desc = 'Format buffer', fn = function(ctx)
        if ctx.buf:is_valid() then ctx.buf:format() end
    end })

    self.actions:register('file.open', { desc = 'Open file', fn = function() self.ui.finder:files() end })
    self.actions:register('file.explorer', { desc = 'File explorer', fn = function() self.ui.tree:toggle() end })
    self.actions:register('file.grep', { desc = 'Search in files', fn = function() self.ui.finder:grep() end })
    self.actions:register('file.recent', { desc = 'Recent files', fn = function() self.ui.finder:recent() end })

    self.actions:register('view.options', { desc = 'Options', fn = function() self.config:manage() end })
    self.actions:register('view.buffers', { desc = 'Open buffers', fn = function() self.ui.finder:buffers() end })
    self.actions:register('view.diagnostics', { desc = 'Diagnostics', fn = function() self.ui.finder:diagnostics() end })
    self.actions:register('view.symbols', { desc = 'Document symbols', fn = function() self.ui.finder:symbols() end })

    self.actions:register('editor.close', { desc = 'Close buffer', fn = function(ctx)
        if ctx.buf:is_valid() then ctx.buf:close() end
    end })

    self.actions:register('file.new', { desc = 'New file', fn = function() vim.cmd('enew') end })

    self.actions:register('view.references', { desc = 'References', fn = function()
        pcall(function() self.ui.finder:references() end)
    end })
    self.actions:register('view.keymaps', { desc = 'Keymaps', fn = function()
        pcall(function() self.ui.finder:keymaps() end)
    end })

    self.actions:register('lsp.hover', { desc = 'Hover documentation', fn = function(ctx)
        ctx.buf:lsp():hover()
    end })
    self.actions:register('lsp.definition', { desc = 'Go to definition', fn = function(ctx)
        ctx.buf:lsp():definition()
    end })
    self.actions:register('lsp.references', { desc = 'Find references', fn = function(ctx)
        ctx.buf:lsp():references()
    end })
    self.actions:register('lsp.rename', { desc = 'Rename symbol', fn = function(ctx)
        ctx.buf:lsp():rename()
    end })
    self.actions:register('lsp.codeAction', { desc = 'Code action', fn = function(ctx)
        ctx.buf:lsp():code_action()
    end })

    self.actions:register('git.lazygit', { desc = 'Open LazyGit', fn = function()
        pcall(function() self.shell:floating('lazygit', { title = 'LazyGit' }) end)
    end })

    self.actions:register('debug.continue', { desc = 'Debug: Continue', fn = function()
        self.debug:continue()
    end })
    self.actions:register('debug.toggleBreakpoint', { desc = 'Debug: Toggle breakpoint', fn = function()
        self.debug:toggle_breakpoint()
    end })
    self.actions:register('debug.stepOver', { desc = 'Debug: Step over', fn = function()
        self.debug:step_over()
    end })
    self.actions:register('debug.stepInto', { desc = 'Debug: Step into', fn = function()
        self.debug:step_into()
    end })

    self.actions:register('editor.selectAll', { desc = 'Select all', fn = function(ctx)
        if ctx.buf:is_normal() then ctx.buf:select_all() end
    end })
    self.actions:register('editor.comment', { desc = 'Toggle comment', fn = function(ctx)
        if ctx.buf:is_normal() then ctx.buf:toggle_comment() end
    end })
    self.actions:register('editor.moveLineUp', { desc = 'Move line up', fn = function(ctx)
        if ctx.buf:is_normal() then ctx.buf:move_line_up() end
    end })
    self.actions:register('editor.moveLineDown', { desc = 'Move line down', fn = function(ctx)
        if ctx.buf:is_normal() then ctx.buf:move_line_down() end
    end })
    self.actions:register('editor.duplicateLine', { desc = 'Duplicate line', fn = function(ctx)
        if ctx.buf:is_normal() then ctx.buf:duplicate_line() end
    end })

    self.actions:register('file.save', { desc = 'Save', fn = function(ctx)
        if ctx.buf:is_valid() then ctx.buf:save() end
    end })
    self.actions:register('file.saveAs', { desc = 'Save As...', fn = function(ctx)
        if not ctx.buf:is_valid() then return end
        vim.ui.input({ prompt = 'Save as: ', default = ctx.buf:path() or '' }, function(path)
            if path and path ~= '' then
                vim.cmd('saveas ' .. vim.fn.fnameescape(path))
                self.ui:info('Saved as ' .. path)
            end
        end)
    end })
    self.actions:register('file.rename', { desc = 'Rename file', fn = function()
        self.commands:execute('Rename')
    end })
    self.actions:register('file.delete', { desc = 'Delete file', fn = function()
        self.commands:execute('Delete')
    end })
    self.actions:register('file.copyPath', { desc = 'Copy file path', fn = function(ctx)
        if ctx.buf:is_valid() and ctx.buf:path() then
            self.text:to_clipboard(ctx.buf:path())
            self.ui:info('Path copied')
        end
    end })

    self.actions:register('view.quickfix', { desc = 'Quick Fix list', fn = function()
        self.commands:execute('IDEQuickFix')
    end })
    self.actions:register('view.ideStatus', { desc = 'IDE Status', fn = function()
        self.commands:execute('IDEStatus')
    end })
    self.actions:register('view.extensions', { desc = 'Extensions', fn = function()
        self.commands:execute('IDEExtensions')
    end })

    self.actions:register('lsp.format', { desc = 'Format document', fn = function(ctx)
        if ctx.buf:is_normal() then ctx.buf:format() end
    end })
    self.actions:register('lsp.signatureHelp', { desc = 'Signature help', fn = function(ctx)
        if ctx.buf:is_normal() then ctx.buf:lsp():signature_help() end
    end })

    self.actions:register('debug.stop', { desc = 'Debug: Stop', fn = function()
        self.debug:stop()
    end })
    self.actions:register('debug.stepOut', { desc = 'Debug: Step out', fn = function()
        self.debug:step_out()
    end })

    self.actions:register('window.cycle', { desc = 'Next window', fn = function()
        require('ide.Window').cycle()
    end })
    self.actions:register('window.splitH', { desc = 'Split horizontal', fn = function()
        if self._window_chrome then
            self._window_chrome:split_horizontal()
        end
    end })
    self.actions:register('window.splitV', { desc = 'Split vertical', fn = function()
        if self._window_chrome then
            self._window_chrome:split_vertical()
        end
    end })
    self.actions:register('window.equalize', { desc = 'Equalize windows', fn = function()
        require('ide.Window').equalize()
    end })
    self.actions:register('window.closeOthers', { desc = 'Close other windows', fn = function()
        require('ide.Window').close_others()
    end })

    self.actions:register('app.quit', { desc = 'Quit', fn = function() self:quit() end })
    self.actions:register('app.help', { desc = 'Help', fn = function() self:help() end })
    self.actions:register('app.healthcheck', { desc = 'Health check', fn = function() self:healthcheck() end })
    self.actions:register('app.keyHints', { desc = 'Key hints', fn = function() self.keys:show_hints('<leader>', 'n') end })
    self.actions:register('app.menu', { desc = 'Open menu', fn = function() self.menu_bar:open('&File') end })
end

-- Re-export classes for direct use
IDE.Buffer = require 'ide.Buffer'
IDE.Window = require 'ide.Window'
IDE.Position = require 'ide.Position'
IDE.LspServer = require 'ide.LspServer'
IDE.Project = Project
IDE.EventEmitter = EventEmitter
IDE.Highlight = require 'ide.Highlight'
IDE.Extension = require 'ide.Extension'
IDE.Command = Command
IDE.Timer = Timer
IDE.DiagnosticSet = require 'ide.DiagnosticSet'
IDE.FormatterRunner = FormatterRunner
IDE.LinterRunner = LinterRunner
IDE.ProgressTracker = ProgressTracker
IDE.toolkit = require 'ide.toolkit'

---@return string
function IDE:__tostring()
    local proj = self._project
    return string.format('IDE(buffers=%d, windows=%d, lsp=%s, project=%s)',
        self.buffers:count(),
        self.windows:count(),
        tostring(self.lsp),
        proj and proj:name() or '?'
    )
end

-- Singleton
return IDE()
