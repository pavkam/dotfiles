local dap = require 'dap'
local dap_ui = require 'dap.ui'
local utils = require 'utils'
local js_project = require 'utils.project.js'
local go_project = require 'utils.project.go'
local python_project = require 'utils.project.python'
local dotnet_project = require 'utils.project.dotnet'
local project_internals = require 'utils.project.internals'

local M = {}

M.root = project_internals.root

function M.type(target)
    return (js_project.type(target) or go_project.type(target) or python_project.type(target) or dotnet_project.type(target))
end

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

function M.continue_debugging(target)
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

return M
