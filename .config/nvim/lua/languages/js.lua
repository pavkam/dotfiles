local utils = require 'core.utils'
local project_internals = require 'languages.internals'

local bin_filetypes = { 'typescript', 'javascript' }
local jsx_filetypes = { 'typescriptreact', 'javascriptreact' }
local filetypes = vim.tbl_flatten { bin_filetypes, jsx_filetypes }

---@class utils.project.js
local M = {}

--- Checks if a parsed package.json has a dependency
---@param parsed_json table<string, any> # the parsed package.json
---@param dep_type string # the type of the dependency
---@param dependency string # the name of the dependency
---@return boolean # whether the dependency exists
local function parsed_package_json_has_dependency(parsed_json, dep_type, dependency)
    assert(type(parsed_json) == 'table')
    assert(type(dep_type) == 'string' and dep_type ~= '')
    assert(type(dependency) == 'string' and dependency ~= '')

    if parsed_json[dep_type] then
        for key, _ in pairs(parsed_json[dep_type]) do
            if key == dependency then
                return true
            end
        end
    end

    return false
end

--- Reads a package.json for a given target
---@param target string|integer|nil # the target to read the package.json for
---@return table<string, any>|nil # the parsed package.json
local function read_package_json(target)
    local full_name = utils.first_found_file(project_internals.roots(target), 'package.json')

    local json_content = full_name and utils.read_text_file(full_name)
    return json_content and vim.json.decode(json_content)
end

--- Checks if a target has a dependency
---@param target string|integer|nil # the target to check the dependency for
---@param dependency string # the name of the dependency
---@return boolean # whether the dependency exists
function M.has_dependency(target, dependency)
    local parsed_json = read_package_json(target)
    if not parsed_json then
        return false
    end

    return (
        parsed_package_json_has_dependency(parsed_json, 'dependencies', dependency)
        or parsed_package_json_has_dependency(parsed_json, 'devDependencies', dependency)
    )
end

--- Gets the path to a binary for a given target
---@param target string|integer|nil # the target to get the binary path for
---@param bin string|nil # the path of the binary
function M.get_bin_path(target, bin)
    local sub = utils.join_paths('node_modules', '.bin', bin)
    ---@cast sub string

    return utils.first_found_file(project_internals.roots(target), sub)
end

--- Gets the path to the eslint config for a given target
---@param target string|integer|nil # the target to get the eslint config for
---@return string|nil # the path to the eslint config
function M.get_eslint_config_path(target)
    return utils.first_found_file(project_internals.roots(target), { '.eslintrc.json', '.eslintrc.js', 'eslint.config.js', 'eslint.config.json' })
end

--- Returns the type of the project
---@param target string|integer|nil # the target to get the type for
---@return string|nil # the type of the project
function M.type(target)
    local package = read_package_json(target)

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
        cwd = '${workspaceFolder}',
    },
    pwa_node_attach = {
        type = 'pwa-node',
        request = 'attach',
        name = 'Attach',
        processId = function()
            return require('dap.utils').pick_process()
        end,
        cwd = '${workspaceFolder}',
    },
    pwa_node_jest = {
        type = 'pwa-node',
        request = 'launch',
        name = 'Debug Jest Tests',
        runtimeExecutable = 'node',
        runtimeArgs = function(path)
            return {
                M.get_bin_path(path, 'jest'),
                '--runInBand',
            }
        end,
        rootPath = '${workspaceFolder}',
        cwd = '${workspaceFolder}',
        console = 'integratedTerminal',
        internalConsoleOptions = 'neverOpen',
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
        webRoot = '${workspaceFolder}',
    },
    pwa_chrome_launch = {
        type = 'pwa-chrome',
        name = 'Launch Chrome',
        request = 'launch',
        url = 'http://localhost:5173', -- This is for Vite. Change it to the framework you use
        webRoot = '${workspaceFolder}',
        userDataDir = '${workspaceFolder}/.vscode/vscode-chrome-debug-userdatadir',
    },
}

--- Configures debugging for a given target
---@param target string|integer|nil # the target to configure debugging for
function M.configure_debugging(target)
    local dap = require 'dap'
    local dap_vscode = require 'dap.ext.vscode'

    for _, language in ipairs(bin_filetypes) do
        dap.configurations[language] = {
            dap_configurations.pwa_node_launch,
            dap_configurations.pwa_node_attach,
            dap_configurations.pwa_node_jest,
            dap_configurations.pwa_chrome_launch,
        }
    end

    for _, language in ipairs(jsx_filetypes) do
        dap.configurations[language] = {
            dap_configurations.pwa_chrome_attach,
            dap_configurations.pwa_chrome_launch,
        }
    end

    -- potentially load the launch.json
    local launch_json = project_internals.get_launch_json(target)
    if launch_json then
        dap_vscode.load_launchjs(launch_json, {
            ['pwa-node'] = filetypes,
            ['node'] = filetypes,
            ['chrome'] = filetypes,
            ['pwa-chrome'] = filetypes,
        })
    end
end

return M
