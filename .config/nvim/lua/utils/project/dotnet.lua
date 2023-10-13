local dap = require 'dap'
local dap_vscode = require 'dap.ext.vscode'

local utils = require "utils"
local project_internals = require "utils.project.internals"

local M = {}

function M.type(path)
    local root = project_internals.get_project_root_dir(path)

    if root and #vim.fn.globpath(root, '*.sln', 0, 1) > 0 then
        return 'dotnet'
    end

    return nil
end

local function get_dll()
	return coroutine.create(function(dap_run_co)
		local items = vim.fn.globpath(vim.fn.getcwd(), '**/bin/Debug/**/*.dll', 0, 1)
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
	}
}

function M.configure_debugging(path)
    dap.configurations.coreclr = utils.tbl_copy(dap_configurations)

    local launch_json = project_internals.get_launch_json(path)
    if launch_json then
        dap_vscode.load_launchjs(launch_json)
    end
end

return M
