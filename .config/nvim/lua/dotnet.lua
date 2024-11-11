local project = require 'project'

--- Gets the launch DLL for a given target
---@param target string|integer|nil # the target to get the launch DLL for
---@return thread # the coroutine to get the DLL
local function get_dll(target)
    return coroutine.create(function(dap_run_co)
        ---@diagnostic disable-next-line: param-type-mismatch
        local items = vim.fn.globpath(project.root(target), '**/bin/Debug/**/*.dll', 0, 1)
        local opts = {
            format_item = function(path)
                return vim.fn.fnamemodify(path, ':t')
            end,
        }

        local function cont(choice)
            if choice == nil then
                return nil
            else
                coroutine.resume(dap_run_co, choice)
            end
        end

        vim.ui.select(items, opts, cont)
    end)
end

local dap_configurations = {
    {
        type = 'coreclr',
        name = 'Project',
        request = 'launch',
        cwd = '${fileDirname}',
        program = get_dll,
    },
}

--- Configures debugging for a given target
---@param target string|integer|nil # the target to configure debugging for
return function(target)
    local dap = require 'dap'
    local dap_vscode = require 'dap.ext.vscode'

    dap.configurations.coreclr = vim.tbl_extend('force', {}, dap_configurations)

    local launch_json = project.get_launch_json(target)
    if launch_json then
        dap_vscode.load_launchjs(launch_json)
    end
end
