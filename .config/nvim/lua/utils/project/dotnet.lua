local dap = require 'dap'
local dap_vscode = require 'dap.ext.vscode'

local utils = require 'utils'
local project_internals = require 'utils.project.internals'

local M = {}

--- Returns the type of the project
---@param target string|integer|nil # the target to get the type for
---@return string|nil # the type of the project
function M.type(target)
    local root = project_internals.root(target)

    ---@diagnostic disable-next-line: param-type-mismatch
    if root and #vim.fn.globpath(root, '*.sln', 0, 1) > 0 then
        return 'dotnet'
    end

    return nil
end

--- Gets the launch DLL for a given target
---@param target string|integer|nil # the target to get the launch DLL for
---@return thread # the coroutine to get the DLL
local function get_dll(target)
    return coroutine.create(function(dap_run_co)
        ---@diagnostic disable-next-line: param-type-mismatch
        local items = vim.fn.globpath(project_internals.root(target), '**/bin/Debug/**/*.dll', 0, 1)
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
function M.configure_debugging(target)
    dap.configurations.coreclr = utils.tbl_copy(dap_configurations)

    local launch_json = project_internals.get_launch_json(target)
    if launch_json then
        dap_vscode.load_launchjs(launch_json)
    end
end

return M
