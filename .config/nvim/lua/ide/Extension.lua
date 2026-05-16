-- Extension: base class for IDE extensions.
-- Extensions register themselves with the IDE and receive a context
-- object that lets them add keymaps, commands, hooks, and UI components.
-- Extensions can be enabled/disabled at runtime.
--
-- Usage:
--   local MyExt = Class('MyExt', Extension)
--   function MyExt:on_register(ctx)
--     ctx:command('MyCmd', function() ... end, { desc = '...' })
--     ctx:keymap('n', '<leader>m', function() ... end, { desc = '...' })
--     ctx:hook('BufWritePre', function() ... end)
--   end
--   function MyExt:on_unregister()
--     -- cleanup
--   end
--   IDE:register_extension(MyExt())

local EventEmitter = require 'ide.EventEmitter'

local Extension = Class('Extension')
Class.include(Extension, EventEmitter)

---@param name string
function Extension:init(name)
    assert(type(name) == 'string' and name ~= '', 'extension name required')
    self._name = name
    self._enabled = false
    self._errored = false  ---@type boolean
    self._error = nil      ---@type string|nil
    self._commands = {}  ---@type table[] # registered commands
    self._hooks = {}     ---@type table[] # registered hooks (autocmd ids)
    self._keymaps = {}   ---@type table[] # registered keymaps
    self._menu_contributions = {} ---@type string[] # menu names this extension contributed to
end

---@return string
function Extension:name()
    return self._name
end

---@return boolean
function Extension:is_enabled()
    return self._enabled
end

--- Override in subclasses: called when extension is registered with IDE.
--- Receives a context object for adding commands, keymaps, hooks.
---@param ctx ExtensionContext
function Extension:on_register(ctx) end

--- Override in subclasses: called when extension is unregistered.
function Extension:on_unregister() end

--- Enable this extension (called by IDE:register_extension).
--- Wraps on_register in pcall — a broken extension never takes down the IDE.
function Extension:_enable()
    self._enabled = true
    self._errored = false
    self._error = nil
    self._ctx = self:_create_context()

    local ok, err = pcall(self.on_register, self, self._ctx)
    if not ok then
        self._errored = true
        self._error = tostring(err)
        self:_disable()
        vim.schedule(function()
            vim.notify(
                string.format('[IDE] Extension "%s" failed to load: %s', self._name, self._error),
                vim.log.levels.WARN
            )
        end)
        return
    end

    self:emit('enable')
end

--- Check if extension errored during registration.
---@return boolean
function Extension:is_errored()
    return self._errored
end

--- Get the error message if extension failed.
---@return string|nil
function Extension:error()
    return self._error
end

--- Disable and clean up this extension.
function Extension:_disable()
    -- Let the extension do custom cleanup while resources are still live
    self:on_unregister()

    -- Remove all registered commands
    for _, cmd in ipairs(self._commands) do
        pcall(vim.api.nvim_del_user_command, cmd)
    end
    self._commands = {}

    -- Remove all hooks
    for _, id in ipairs(self._hooks) do
        pcall(vim.api.nvim_del_autocmd, id)
    end
    self._hooks = {}

    -- Remove all registered toggles
    if self._toggles then
        for _, name in ipairs(self._toggles) do
            pcall(IDE.config.unregister_toggle, IDE.config, name)
        end
        self._toggles = {}
    end

    -- Remove all keymaps
    for _, km in ipairs(self._keymaps) do
        pcall(vim.keymap.del, km.mode, km.lhs, km.buffer and { buffer = km.buffer } or {})
    end
    self._keymaps = {}

    -- Remove all highlights
    if self._highlights then
        for _, name in ipairs(self._highlights) do
            pcall(vim.api.nvim_set_hl, 0, name, {})
        end
        self._highlights = {}
    end

    -- Remove all registered actions
    if self._actions then
        for _, name in ipairs(self._actions) do
            if IDE and IDE.actions then
                pcall(IDE.actions.unregister, IDE.actions, name)
            end
        end
        self._actions = {}
    end

    -- Remove all menu contributions
    if self._menu_contributions and #self._menu_contributions > 0 then
        if _G.IDE and IDE.menu_bar then
            IDE.menu_bar:remove_contribution(self._name)
        end
        self._menu_contributions = {}
    end

    self._enabled = false
    self:emit('disable')
end

--- Create the context object that extensions use to register their features.
---@return ExtensionContext
function Extension:_create_context()
    local ext = self

    ---@class ExtensionContext
    local ctx = {}

    --- Register a user command.
    ---@param name string
    ---@param fn function
    ---@param opts { desc?: string, nargs?: string|integer, bang?: boolean, range?: boolean }|nil
    function ctx:command(name, fn, opts)
        opts = opts or {}
        vim.api.nvim_create_user_command(name, fn, {
            desc = opts.desc,
            nargs = opts.nargs or 0,
            bang = opts.bang,
            range = opts.range,
        })
        ext._commands[#ext._commands + 1] = name
    end

    --- Register a keymap.
    ---@param mode string|string[]
    ---@param lhs string
    ---@param rhs function|string
    ---@param opts { desc?: string, buffer?: integer, expr?: boolean }|nil
    function ctx:keymap(mode, lhs, rhs, opts)
        opts = opts or {}

        -- If rhs is a string matching an action name, resolve it through the registry
        local action_name = nil
        local fn = rhs
        if type(rhs) == 'string' and rhs:find('%.') and IDE and IDE.actions:has(rhs) then
            action_name = rhs
            fn = function() IDE.actions:execute(action_name) end
            if not opts.desc then
                opts.desc = IDE.actions:desc(action_name)
            end
        end

        vim.keymap.set(mode, lhs, fn, {
            desc = opts.desc,
            buffer = opts.buffer,
            expr = opts.expr,
            silent = true,
        })
        ext._keymaps[#ext._keymaps + 1] = {
            mode = mode, lhs = lhs, buffer = opts.buffer, action = action_name,
        }
        -- Register with KeyHint for auto-popup
        if opts.desc and not opts.buffer and IDE and IDE.keys then
            local modes = type(mode) == 'table' and mode or { mode }
            for _, m in ipairs(modes) do
                IDE.keys:hints():register(m, lhs, opts.desc)
            end
        end
    end

    --- Register a named action in the ActionRegistry.
    ---@param name string # dot-separated like 'editor.save'
    ---@param desc string
    ---@param fn function
    function ctx:action(name, desc, fn)
        if IDE and IDE.actions then
            IDE.actions:register(name, { desc = desc, fn = fn })
            ext._actions = ext._actions or {}
            ext._actions[#ext._actions + 1] = name
        end
    end

    --- Register an autocommand hook.
    ---@param events string|string[]
    ---@param fn function
    ---@param opts { pattern?: string|string[], buffer?: integer, desc?: string, once?: boolean }|nil
    function ctx:hook(events, fn, opts)
        opts = opts or {}
        local id = vim.api.nvim_create_autocmd(events, {
            callback = fn,
            pattern = opts.pattern,
            buffer = opts.buffer,
            once = opts.once,
            desc = opts.desc or (ext._name .. ' hook'),
        })
        ext._hooks[#ext._hooks + 1] = id
    end

    --- Access the IDE singleton.
    ---@return table
    function ctx:ide()
        return _G.IDE
    end

    --- Register a config toggle (auto-cleaned on extension disable).
    ---@param name string
    ---@param opts { desc?: string, default?: boolean, on_toggle?: fun(enabled: boolean), scope?: string }|nil
    function ctx:toggle(name, opts)
        IDE.config:register_toggle(name, opts)
        ext._toggles = ext._toggles or {}
        ext._toggles[#ext._toggles + 1] = name
    end

    --- Show a notification.
    ---@param msg string
    ---@param level? string # 'info'|'warn'|'error'
    function ctx:notify(msg, level)
        local fn = (level == 'error' and IDE.ui.error)
            or (level == 'warn' and IDE.ui.warn)
            or IDE.ui.info
        fn(IDE.ui, msg, { title = ext._name })
    end

    --- Schedule a function to run on the main loop (skipped if extension was disabled).
    ---@param fn function
    function ctx:schedule(fn)
        vim.schedule(function()
            if ext._enabled then fn() end
        end)
    end

    --- Defer a function by milliseconds (skipped if extension was disabled).
    ---@param ms integer
    ---@param fn function
    function ctx:defer(ms, fn)
        vim.defer_fn(function()
            if ext._enabled then fn() end
        end, ms)
    end

    --- Register a highlight group (auto-cleaned on disable).
    ---@param name string
    ---@param opts table # { fg, bg, bold, italic, ... }
    function ctx:highlight(name, opts)
        IDE.theme:define(name, opts)
        ext._highlights = ext._highlights or {}
        ext._highlights[#ext._highlights + 1] = name
    end

    --- Link a highlight group (auto-cleaned on disable).
    ---@param name string
    ---@param target string
    function ctx:link_highlight(name, target)
        IDE.theme:link(name, target)
        ext._highlights = ext._highlights or {}
        ext._highlights[#ext._highlights + 1] = name
    end

    --- Contribute menu items to a named menu (auto-cleaned on disable).
    ---@param menu_name string   -- e.g. 'File', 'Edit', 'Build'
    ---@param items table[]      -- MenuItem instances
    function ctx:menu(menu_name, items)
        if not _G.IDE or not IDE.menu_bar then return end
        IDE.menu_bar:contribute(menu_name, ext._name, items)
        ext._menu_contributions = ext._menu_contributions or {}
        if not vim.tbl_contains(ext._menu_contributions, menu_name) then
            ext._menu_contributions[#ext._menu_contributions + 1] = menu_name
        end
    end

    return ctx
end

---@return string
function Extension:__tostring()
    local status = self._errored and 'errored' or (self._enabled and 'enabled' or 'disabled')
    return string.format('Extension(%s, %s)', self._name, status)
end

return Extension
