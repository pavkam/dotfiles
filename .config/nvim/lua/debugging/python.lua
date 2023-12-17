local utils = require 'core.utils'
local project = require 'project'

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
return function(target)
    local dap = require 'dap'
    local dap_vscode = require 'dap.ext.vscode'

    dap.configurations.python = vim.tbl_extend('force', {}, dap_configurations)

    local launch_json = project_internals.get_launch_json(target)
    if launch_json then
        dap_vscode.load_launchjs(launch_json)
    end
end
