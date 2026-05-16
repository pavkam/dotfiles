local dap_configurations = {
    {
        type = 'python',
        request = 'launch',
        name = 'Current File',
        program = '${file}',
        pythonPath = IDE.shell:exepath('python3') or IDE.shell:exepath('python'),
    },
}

--- Configures debugging for a given target
---@param target string|integer|nil # the target to configure debugging for
return function(target)
    local dap = require 'dap'
    local dap_vscode = require 'dap.ext.vscode'

    dap.configurations.python = vim.tbl_extend('force', {}, dap_configurations)

    local proj = IDE:project()
    local launch_json = proj and proj:launch_json() or nil
    if launch_json then
        dap_vscode.load_launchjs(launch_json)
    end
end
