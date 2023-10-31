local dap = require 'dap'
local dap_vscode = require 'dap.ext.vscode'

local utils = require 'utils'
local project_internals = require 'utils.project.internals'

local M = {}

function M.get_golangci_config(target)
    return utils.first_found_file(project_internals.roots(target), { '.golangci.yml', '.golangci.yaml', '.golangci.toml', '.golangci.json' })
end

function M.type(target)
    if utils.first_found_file(project_internals.roots(target), { 'go.mod', 'go.sum' }) then
        return 'go'
    end

    return nil
end

local dap_configurations = {
    {
        type = 'go',
        name = 'Debug',
        request = 'launch',
        program = './${relativeFileDirname}',
    },
    {
        type = 'go',
        name = 'Debug Test',
        request = 'launch',
        mode = 'test',
        program = '${file}',
    },
    {
        type = 'go',
        name = 'Debug Tests (go.mod)',
        request = 'launch',
        mode = 'test',
        program = './${relativeFileDirname}',
    },
}

function M.configure_debugging(target)
    dap.configurations.go = utils.tbl_copy(dap_configurations)

    local launch_json = project_internals.get_launch_json(target)
    if launch_json then
        dap_vscode.load_launchjs(launch_json)
    end
end

return M
