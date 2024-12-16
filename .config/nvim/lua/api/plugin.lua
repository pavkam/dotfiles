local fs = require 'api.fs'

--- Provides functionality for interacting with plugins.
---@class plugins
local M = {}

--- Checks if a plugin is available
---@param name string # the name of the plugin
---@return boolean # true if the plugin is available, false otherwise
function M.has(name)
    assert(type(name) == 'string' and name ~= '')

    if package.loaded['lazy'] then
        return require('lazy.core.config').spec.plugins[name] ~= nil
    end

    return false
end

--- Returns the configuration of a plugin
---@param name string # the name of the plugin
---@return table<string, any>|nil # the configuration of the plugin
function M.config(name)
    assert(type(name) == 'string' and name ~= '')

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

    local actual_path = fs.join_paths(fs.DATA_DIRECTORY, path)

    if not fs.directory_exists(actual_path) then
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
                require('api.process').fatal(message)
            else
                require('api.tui').error(message)
            end

            return false
        end
    end

    vim.opt.rtp:prepend(actual_path)
    return true
end

--- Slot that triggers when a plugin is loaded.
---@type evt_slot<{ plugin: string }>
M.loaded = require('api.process')
    .observe_auto_command({ 'User' }, {
        description = 'Triggers when a plugin is loaded.',
        patterns = { 'LazyLoad' },
        group = 'plugin.loaded',
    })
    .continue(function(data)
        return type(data.data) == 'string' and {
            plugin = data.data,
        } or nil
    end)

return table.freeze(M)
