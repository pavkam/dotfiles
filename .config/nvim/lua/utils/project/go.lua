local dap = require 'dap'
local dap_vscode = require 'dap.ext.vscode'

local utils = require "utils"
local project_internals = require "utils.project.internals"

local M = {}

function M.get_golangci_config(path)
    local root = project_internals.get_project_root_dir(path)
    return root and utils.any_file_exists(root, { '.golangci.yml', '.golangci.yaml', '.golangci.toml', '.golangci.json' })
end

function M.type(path)
    local root = project_internals.get_project_root_dir(path)
    if root and utils.any_file_exists(root, { 'go.mod', 'go.sum' }) then
        return 'go'
    end

    return nil
end

local original_go_configurations = nil

function M.configure_debugging(path)
    if original_go_configurations == nil then
        original_go_configurations = dap.configurations.go
    end

    dap.configurations.go = original_go_configurations

    local launch_json = project_internals.get_launch_json(path)
    if launch_json then
        dap_vscode.load_launchjs(launch_json)
    end
end

return M
