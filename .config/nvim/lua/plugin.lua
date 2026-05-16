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

    local actual_path = path

    if vim.fn.isdirectory(actual_path) == 0 then
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
                vim.api.nvim_err_writeln(message)
                vim.cmd('cquit!')
            else
                vim.notify(message, vim.log.levels.ERROR)
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

    local id = vim.api.nvim_create_autocmd('User', {
        pattern = 'LazyLoad',
        callback = function(args)
            if args.data == name then
                callback(args)
            end
        end,
        once = true,
        desc = string.format('plugin: on_loaded(%s)', name),
    })
    return function() pcall(vim.api.nvim_del_autocmd, id) end
end

-- Creates a plugin slot.
---@param name string # the name of the plugin slot.
---@return table # the plugin slot.

return table.freeze(M)
