local utils = require 'core.utils'
local js_project = require 'languages.js'
local go_project = require 'languages.go'
local python_project = require 'languages.python'
local dotnet_project = require 'languages.dotnet'
local project_internals = require 'languages.internals'

---@class utils.project
local M = {}

M.root = project_internals.root
M.roots = project_internals.roots

--- Returns the type of the project
---@param target string|integer|nil # the target to get the type for
---@return string|nil # the type of the project
function M.type(target)
    return (js_project.type(target) or go_project.type(target) or python_project.type(target) or dotnet_project.type(target))
end

--- Configures debugging for a given target
---@param target string|integer|nil # the target to configure debugging for
---@return boolean # whether the debugging was configured
local function setup_debugging(target)
    if js_project.type(target) then
        js_project.configure_debugging()
    elseif go_project.type(target) then
        go_project.configure_debugging()
    elseif python_project.type(target) then
        python_project.configure_debugging()
    elseif dotnet_project.type(target) then
        dotnet_project.configure_debugging()
    else
        return false
    end

    return true
end

--- Starts or continues debugging for a given target
---@param target string|integer|nil # the target to start or continue debugging for
function M.continue_debugging(target)
    local dap = require 'dap'
    local dap_ui = require 'dap.ui'

    local current_session = dap.session()
    if not current_session then
        if not setup_debugging(target) then
            utils.error 'No debugging configuration found for this project type.'
            return
        end
    end

    local project_type = M.type(target)
    if not current_session and project_type and #dap.configurations[project_type] > 0 then
        dap_ui.pick_if_many(dap.configurations[project_type], 'Configuration: ', function(i)
            return i.name
        end, function(configuration)
            if configuration then
                utils.info("Starting debugging session '" .. configuration.name .. "' ...")

                dap.run(configuration, { filetype = project_type })
            end
        end)
    elseif current_session then
        utils.info("Resuming debugging session '" .. current_session.config.name .. "' ...")
        dap.continue()
    end
end

--- Gets the dap configurations for a given target
---@param target string|integer|nil # the target to get the dap configurations for
---@return Configuration[] # the dap configurations
function M.dap_configurations(target)
    local dap = require 'dap'

    if not dap.session() then
        if not setup_debugging(target) then
            return {}
        end
    end

    local project_type = M.type(target)
    return project_type and dap.configurations[project_type] or {}
end

return M
