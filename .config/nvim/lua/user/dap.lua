local neotest_lib = require("neotest.lib")
local nio = require("nio")
local dap = require('dap')
local dap_utils = require('dap.utils')
local dap_vscode = require('dap.ext.vscode')

local pwa_node_launch_config = {
    type = 'pwa-node',
    request = 'launch',
    name = 'Launch file',
    program = '${file}',
    cwd = '${workspaceFolder}'
}

local pwa_node_attach_config = {
    type = 'pwa-node',
    request = 'attach',
    name = 'Attach',
    processId = dap_utils.pick_process,
    cwd = '${workspaceFolder}'
}

local pwa_node_jest_config = {
    type = 'pwa-node',
    request = 'launch',
    name = 'Debug Jest Tests',
    runtimeExecutable = 'node',
    runtimeArgs = {'./node_modules/jest/bin/jest.js', '--runInBand'},
    rootPath = '${workspaceFolder}',
    cwd = '${workspaceFolder}',
    console = 'integratedTerminal',
    internalConsoleOptions = 'neverOpen'
}

local pwa_chrome_attach_config = {
    type = 'pwa-chrome',
    name = 'Attach - Remote Debugging',
    request = 'attach',
    program = '${file}',
    cwd = vim.fn.getcwd(),
    sourceMaps = true,
    protocol = 'inspector',
    port = 9222, -- Start Chrome google-chrome --remote-debugging-port=9222
    webRoot = '${workspaceFolder}'
}

local pwa_chrome_launch_config = {
    type = 'pwa-chrome',
    name = 'Launch Chrome',
    request = 'launch',
    url = 'http://localhost:5173', -- This is for Vite. Change it to the framework you use
    webRoot = '${workspaceFolder}',
    userDataDir = '${workspaceFolder}/.vscode/vscode-chrome-debug-userdatadir'
}

local js_ts_filetypes = {'typescript', 'javascript'}
local jsx_tsx_filetypes = {'typescriptreact', 'javascriptreact'}
local all_js_ts_filetypes = vim.tbl_flatten {js_ts_filetypes, jsx_tsx_filetypes}
local all_go_filetypes = { 'go' }

local package_json_name = "project.json"
local git_root = ".git"

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read "*a"
    file:close()
    return content
end

local function find_root(path, ...)
    return neotest_lib.files.match_root_pattern(..., git_root)(path)
end

local function get_launch_json_path(path, ...)
    local root = find_root(path, ...)

    if not root then
        return false
    end

    local full_path = root .. "/.vscode/launch.json"
    if neotest_lib.files.exists(full_path) then
        return full_path
    end

    return false
end

local function package_json_has_dependency(path, dependency)
    local root = find_root(path, package_json_name)

    if not root then
        return false
    end

    local success, json_content = pcall(read_file, root .. "/package.json")
    if not success then
        return false
    end

    local parsed_json = vim.json.decode(json_content)

    if parsed_json["dependencies"] then
        for key, _ in pairs(parsed_json["dependencies"]) do
            if key == dependency then
                return true
            end
        end
    end

    if parsed_json["devDependencies"] then
        for key, _ in pairs(parsed_json["devDependencies"]) do
            if key == dependency then
                return true
            end
        end
    end

    return false
end

local function get_node_modules_relative_path(path, sub_path)
    local root = find_root(path, package_json_name)

    if not root then
        return false
    end

    local full_path = root .. "/node_modules/" .. sub_path
    if neotest_lib.files.exists(full_path) then
        return full_path
    end

    return false
end

local function get_project_jest_binary(path)
    if not package_json_has_dependency(path, 'jest') then
        return false
    end

    return get_node_modules_relative_path(path, 'jest/bin/jest.js')
end

local original_all_js_ts_config = {}
for _, language in ipairs(all_js_ts_filetypes) do
    original_all_js_ts_config[language] = dap.configurations[language] or {}
end

local configure_javascript_debugging = function()
    local launch_json_path = get_launch_json_path(vim.fn.getcwd(), package_json_name)
    if launch_json_path then
        dap_vscode.load_launchjs(launch_json_path, {
            ['pwa-node'] = all_js_ts_filetypes,
            ['node'] = all_js_ts_filetypes,
            ['chrome'] = all_js_ts_filetypes,
            ['pwa-chrome'] = all_js_ts_filetypes
        })
    end

    for _, language in ipairs(js_ts_filetypes) do
        local configurations = vim.tbl_extend('force', original_all_js_ts_config[language], {
            pwa_node_launch_config,
            pwa_node_attach_config,
            pwa_chrome_attach_config,
            pwa_chrome_launch_config,
        })

        jest_binary = get_project_jest_binary(vim.fn.getcwd())
        if jest_binary then
            table.insert(configurations, vim.tbl_extend('force', pwa_node_jest_config, {
                runtimeArgs = {jest_binary, '--runInBand'},
            }))
        end

        dap.configurations[language] = configurations
    end

    for _, language in ipairs(jsx_tsx_filetypes) do
        dap.configurations[language] = vim.tbl_extend('force', original_all_js_ts_config[language], {
            pwa_chrome_attach_config,
            pwa_chrome_launch_config,
        })
    end
end

local original_go_config = dap.configurations.go
local configure_go_debugging = function()
    dap.configurations.go = original_go_config
    local launch_json_path = get_launch_json_path(vim.fn.getcwd(), 'go.mod', 'go.sum')
    if launch_json_path then
        dap_vscode.load_launchjs(launch_json_path)
    end
end


return {
    setup = function(filetype)
        if vim.tbl_contains(all_js_ts_filetypes, filetype) then
            configure_javascript_debugging()
        end
        if vim.tbl_contains(all_go_filetypes, filetype) then
            configure_go_debugging()
        end
    end
}
