--- Provides functionality for interacting with plugins.
---@class plugins
local M = {}

--- Checks if a plugin is available
---@param name string # the name of the plugin
---@return boolean # true if the plugin is available, false otherwise
function M.has(name)
    xassert { name = { name, { 'string', ['>'] = 0 } } }

    if package.loaded['lazy'] then
        return require('lazy.core.config').spec.plugins[name] ~= nil
    end

    return false
end

--- Returns the configuration of a plugin
---@param name string # the name of the plugin
---@return table<string, any>|nil # the configuration of the plugin
function M.config(name)
    xassert { name = { name, { 'string', ['>'] = 0 } } }

    if package.loaded['lazy'] then
        local plugin = require('lazy.core.config').spec.plugins[name]
        return plugin and require('lazy.core.plugin').values(plugin, 'opts', false)
    end
end

---@class plugins.require_online_opts # Options to require online plugins.
---@field branch string|nil # the branch to clone.
---@field include_blobs boolean|nil # whether to include blobs.
---@field quit boolean|nil # whether to quit the process if the plugin is not available.

-- Require a plugin from an online repository.
---@param url string # the URL of the repository.
---@param path string # the path to clone the repository to.
---@param opts plugins.require_online_opts|nil # the options to require the plugin.
---@return boolean # `true` if the plugin is available, `false` otherwise.
function M.require_online(url, path, opts)
    opts = table.merge(opts, { branch = 'stable', include_blobs = false, quit = true })

    xassert {
        url = { url, { 'string', ['>'] = 0 } },
        path = { path, { 'string', ['>'] = 0 } },
        opts = {
            opts,
            {
                branch = { 'string', ['>'] = 0 },
                include_blobs = 'boolean',
                quit = 'boolean',
            },
        },
    }

    local actual_path = ide.fs.join_paths(ide.fs.DATA_DIRECTORY, path)

    if not ide.fs.directory_exists(actual_path) then
        local result = vim.system({
            'git',
            'clone',
            (not opts.include_blobs) and '--filter=blob:none' or nil,
            url,
            opts.branch and string.format('--branch=%s', opts.branch) or nil,
            actual_path,
        }):wait()

        if result.code ~= 0 then
            local message = string.format('failed to clone the repository `%s`: %s', url, result.stderr)
            if opts.quit then
                ide.process.fatal(message)
            else
                ide.tui.error(message)
            end

            return false
        end
    end

    vim.opt.rtp:prepend(actual_path)
    return true
end

-- Triggers when a plugin is loaded.
---@param name string # the name of the plugin.
---@param callback fun(args: vim.auto_command_event_arguments) # the callback to trigger.
---@return fun() # the unsubscribe function.
function M.on_loaded(name, callback)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        fn = { callback, { 'callable' } },
    }

    return ide.sched.subscribe_event('@LazyLoad', function(args)
        if args.data == name then
            callback(args)
        end
    end, {
        description = string.format('Triggers when the plugin `%s` is loaded.', name),
        patterns = { name },
        group = string.format('plugin.loaded.%s', name),
        once = true,
    })
end

---@class (exact) formatter_plugin # Describes a formatter plugin.
---@field status fun(buffer: buffer): table<string, boolean> # gets the status of the supported formatters.
---@field run fun(buffer: buffer, callback: fun(result: boolean|string)) # runs the formatters.

local fmt_subscribe, fmt_trigger = ide.sched.define_event 'FormatterPluginRegistered'

---@type formatter_plugin[]
M.formatter_plugins = {}

--- Registers a formatter plugin.
---@param plugin formatter_plugin # the formatter plugin to register.
function M.register_formatter(plugin)
    xassert {
        plugin = {
            plugin,
            {
                status = 'callable',
                run = 'callable',
            },
        },
    }

    if table.list_any(M.formatter_plugins, plugin) then
        return
    end

    table.insert(M.formatter_plugins, plugin)
    fmt_trigger()
end

--- Triggers when a formatter plugin is registered.
M.on_formatter_registered = function(...)
    fmt_subscribe(...)

    if not table.is_empty(M.formatter_plugins) then
        fmt_trigger()
    end
end

---@class (exact) linter_plugin # Describes a linting plugin.
---@field status fun(buffer: buffer): table<string, boolean> # gets the status of the supported linters.
---@field run fun(buffer: buffer, callback: fun(result: boolean|string)) # runs the linters.

local lint_subscribe, lint_trigger = ide.sched.define_event 'LinterPluginRegistered'

---@type linter_plugin[]
M.linter_plugins = {}

--- Registers a linter plugin.
---@param plugin linter_plugin # the linter plugin to register.
function M.register_linter(plugin)
    xassert {
        plugin = {
            plugin,
            {
                status = 'callable',
                run = 'callable',
            },
        },
    }

    if table.list_any(M.linter_plugins, plugin) then
        return
    end

    table.insert(M.linter_plugins, plugin)
    lint_trigger()
end

--- Triggers when a linter plugin is registered.
M.on_linter_registered = function(...)
    lint_subscribe(...)

    if not table.is_empty(M.linter_plugins) then
        lint_trigger()
    end
end

return table.freeze(M)
