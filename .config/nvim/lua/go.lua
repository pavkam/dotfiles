local project = require 'project'

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
return function(target)
    local dap = require 'dap'
    local dap_vscode = require 'dap.ext.vscode'

    dap.configurations.go = vim.tbl_extend('force', {}, dap_configurations)

    local launch_json = project.get_launch_json(target)
    if launch_json then
        dap_vscode.load_launchjs(launch_json)
    end
end
