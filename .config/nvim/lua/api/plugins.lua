--- Provides functionality for interacting with plugins.
---@class api.plugins
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

return table.freeze(M)
