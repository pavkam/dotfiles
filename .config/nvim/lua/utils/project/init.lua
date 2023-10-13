local dap = require 'dap'
local dap_ui = require 'dap.ui'
local lsp = require "utils.lsp"
local utils = require "utils"
local js_project = require "utils.project.js"
local go_project = require "utils.project.go"
local python_project = require "utils.project.python"
local dotnet_project = require "utils.project.dotnet"
local project_internals = require "utils.project.internals"

local M = {}

M.get_project_root_dir = project_internals.get_project_root_dir

function M.type(path)
    return js_project.type(path) or go_project.type(path) or python_project.type(path) or dotnet_project.type(path)
end

local function setup_debugging(path)
    if js_project.type(path) then
        js_project.configure_debugging()
    elseif go_project.type(path) then
        go_project.configure_debugging()
    elseif python_project.type(path) then
        python_project.configure_debugging()
    elseif dotnet_project.type(path) then
        dotnet_project.configure_debugging()
    else
        return false
    end

    return true
end

function M.continue_debugging(path)
    local current_session = dap.session()
    if not current_session then
        if not setup_debugging(path) then
            utils.error("No debugging configuration found for this project type.")
            return
        end
    end

    local project_type = M.type(path);
    if not current_session and project_type and #dap.configurations[project_type] > 0 then
        dap_ui.pick_if_many(
            dap.configurations[project_type],
            "Configuration: ",
            function(i) return i.name end,
            function(configuration)
                if configuration then
                    dap.run(configuration, { filetype = project_type })
                end
            end
        )
    else
        dap.continue()
    end
end


return M
