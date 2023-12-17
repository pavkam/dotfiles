local utils = require 'core.utils'
local project_internals = require 'languages.internals'

---@class utils.project.go
local M = {}

--- Returns the path to the golangci file for a given target
---@param target string|integer|nil # the target to get the golangci file for
---@return string|nil # the path to the golangci file
function M.get_golangci_config(target)
    return utils.first_found_file(project_internals.roots(target), { '.golangci.yml', '.golangci.yaml', '.golangci.toml', '.golangci.json' })
end

--- Returns the type of the project
---@param target string|integer|nil # the target to get the type for
---@return string|nil # the type of the project
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

--- Configures debugging for a given target
---@param target string|integer|nil # the target to configure debugging for
function M.configure_debugging(target)
    local dap = require 'dap'
    local dap_vscode = require 'dap.ext.vscode'

    dap.configurations.go = vim.tbl_extend('force', {}, dap_configurations)

    local launch_json = project_internals.get_launch_json(target)
    if launch_json then
        dap_vscode.load_launchjs(launch_json)
    end
end

return M
