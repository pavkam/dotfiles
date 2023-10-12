local dap = require 'dap'
local dap_utils = require 'dap.utils'
local dap_vscode = require 'dap.ext.vscode'
local utils = require "utils"
local project_internals = require "utils.project.internals"

local package_json_name = "package.json"
local node_modules_name = "node_modules"

local bin_filetypes = {'typescript', 'javascript'}
local jsx_filetypes = {'typescriptreact', 'javascriptreact'}
local filetypes = vim.tbl_flatten { bin_filetypes, jsx_filetypes }

local M = {}

local function parsed_package_json_has_dependency(parsed_json, type, dependency)
    if parsed_json[type] then
        for key, _ in pairs(parsed_json[type]) do
            if key == dependency then
                return true
            end
        end
    end

    return false
end

local function read_package_json(path)
    local full_name = utils.join_paths(path, package_json_name)

    local json_content = utils.read_text_file(full_name)
    return json_content and vim.json.decode(json_content)
end

function M.has_dependency(path, dependency)
    local root = project_internals.get_project_root_dir(path)

    local parsed_json = root and read_package_json(root)
    if not parsed_json then
        return false
    end

    return (
        parsed_package_json_has_dependency(parsed_json, 'dependencies', dependency) or
        parsed_package_json_has_dependency(parsed_json, 'devDependencies', dependency)
    )
end

function M.get_bin_path(path, bin)
    local root = project_internals.get_project_root_dir(path)
    if not root then
        return nil
    end

    local full_path = utils.join_paths(root, utils.join_paths(node_modules_name, bin))
    if utils.file_exists(full_path) then
        return full_path
    end

    return nil
end

function M.get_eslint_config_path(path)
    local root = project_internals.get_project_root_dir(path)
    local option = root and utils.any_file_exists(root, { '.eslintrc.json', '.eslintrc.js', 'eslint.config.js', 'eslint.config.json' })

    return option and utils.join_paths(root, option)
end

function M.type(path)
    local root = project_internals.get_project_root_dir(path)
    local package = root and read_package_json(root)

    if package then
        if parsed_package_json_has_dependency(package, 'dependencies', 'typescript') then
            if parsed_package_json_has_dependency(package, 'dependencies', 'react') then
                return 'typescriptreact'
            end

            return 'typescript'
        else
            if parsed_package_json_has_dependency(package, 'dependencies', 'react') then
                return 'javascriptreact'
            end

            return 'javascript'
        end
    end

    return nil
end

local dap_configurations = {
    pwa_node_launch = {
        type = 'pwa-node',
        request = 'launch',
        name = 'Launch file',
        program = '${file}',
        cwd = '${workspaceFolder}'
    },
    pwa_node_attach = {
        type = 'pwa-node',
        request = 'attach',
        name = 'Attach',
        processId = dap_utils.pick_process,
        cwd = '${workspaceFolder}'
    },
    pwa_node_jest = {
        type = 'pwa-node',
        request = 'launch',
        name = 'Debug Jest Tests',
        runtimeExecutable = 'node',
        runtimeArgs = { './node_modules/jest/bin/jest.js', '--runInBand' },
        rootPath = '${workspaceFolder}',
        cwd = '${workspaceFolder}',
        console = 'integratedTerminal',
        internalConsoleOptions = 'neverOpen'
    },
    pwa_chrome_attach = {
        type = 'pwa-chrome',
        name = 'Attach - Remote Debugging',
        request = 'attach',
        program = '${file}',
        cwd = '${workspaceFolder}',
        sourceMaps = true,
        protocol = 'inspector',
        port = 9222, -- Start Chrome google-chrome --remote-debugging-port=9222
        webRoot = '${workspaceFolder}'
    },
    pwa_chrome_launch = {
        type = 'pwa-chrome',
        name = 'Launch Chrome',
        request = 'launch',
        url = 'http://localhost:5173', -- This is for Vite. Change it to the framework you use
        webRoot = '${workspaceFolder}',
        userDataDir = '${workspaceFolder}/.vscode/vscode-chrome-debug-userdatadir'
    }
}

local original_dap_configurations = nil

function M.configure_debugging(path)
    -- store the default configurations
    if original_dap_configurations == nil then
        for _, language in ipairs(filetypes) do
            original_dap_configurations[language] = dap.configurations[language] or {}
        end
    end

    -- potentially load the launch.json
    local launch_json = project_internals.get_launch_json(path)
    if launch_json then
        dap_vscode.load_launchjs(launch_json, {
            ['pwa-node'] = filetypes,
            ['node'] = filetypes,
            ['chrome'] = filetypes,
            ['pwa-chrome'] = filetypes
        })
    end

    -- add additional configurations
    for _, language in ipairs(bin_filetypes) do
        local configurations = vim.tbl_extend('force', original_dap_configurations[language], dap_configurations)

        local jest_binary = M.get_bin_path(path, "jest")
        if jest_binary then
            table.insert(configurations, vim.tbl_extend('force', dap_configurations.pwa_node_jest, {
                runtimeArgs = { jest_binary, '--runInBand' },
            }))
        end

        dap.configurations[language] = configurations
    end

    for _, language in ipairs(jsx_filetypes) do
        dap.configurations[language] = vim.tbl_extend('force', original_dap_configurations[language], {
            dap_configurations.pwa_chrome_attach,
            dap_configurations.pwa_chrome_launch,
        })
    end
end

return M
