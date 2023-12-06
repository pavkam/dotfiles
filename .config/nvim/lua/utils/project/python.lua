local dap = require 'dap'
local dap_vscode = require 'dap.ext.vscode'

local utils = require 'utils'
local project_internals = require 'utils.project.internals'

---@class utils.project.python
local M = {}

--- Returns the type of the project
---@param target string|integer|nil # the target to get the type for
---@return string|nil # the type of the project
function M.type(target)
    if utils.first_found_file(project_internals.roots(target), { 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', 'poetry.lock' }) then
        return 'python'
    end

    return nil
end

local dap_configurations = {
    {
        type = 'python',
        request = 'launch',
        name = 'Current File',
        program = '${file}',
        pythonPath = vim.fn.exepath 'python3' or vim.fn.exepath 'python' or nil,
    },
}

--- Configures debugging for a given target
---@param target string|integer|nil # the target to configure debugging for
function M.configure_debugging(target)
    dap.configurations.python = vim.tbl_extend('force', {}, dap_configurations)

    local launch_json = project_internals.get_launch_json(target)
    if launch_json then
        dap_vscode.load_launchjs(launch_json)
    end
end

return M
