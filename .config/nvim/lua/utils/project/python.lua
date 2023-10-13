local dap = require 'dap'
local dap_vscode = require 'dap.ext.vscode'

local utils = require "utils"
local project_internals = require "utils.project.internals"

local M = {}

function M.type(path)
    local root = project_internals.get_project_root_dir(path)
    if root and utils.any_file_exists(root, { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "poetry.lock" }) then
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
		pythonPath = vim.fn.exepath("python3") or vim.fn.exepath("python") or nil
	},
}

function M.configure_debugging(path)
    dap.configurations.python = utils.tbl_copy(dap_configurations)

    local launch_json = project_internals.get_launch_json(path)
    if launch_json then
        dap_vscode.load_launchjs(launch_json)
    end
end

return M
