local project = require 'utils.project'
local dap = require 'dap'
local dap_ui = require 'dap.ui'
local dap_utils = require 'dap.utils'
local dap_vscode = require 'dap.ext.vscode'

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

local original_all_js_ts_config = {}
for _, language in ipairs(all_js_ts_filetypes) do
    original_all_js_ts_config[language] = dap.configurations[language] or {}
end

local configure_javascript_debugging = function()
    local launch_json_path = project.get_project_launch_json_path()
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

        jest_binary = project.get_node_package_jest_binary_path()
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
    local launch_json_path = project.get_project_launch_json_path()
    if launch_json_path then
        dap_vscode.load_launchjs(launch_json_path)
    end
end

local configure_general_debugging = function()
    local launch_json_path = project.get_project_launch_json_path()
    if launch_json_path then
        dap_vscode.load_launchjs(launch_json_path)
    end
end

local M = {
    setup = function(filetype)
        if vim.tbl_contains(all_js_ts_filetypes, filetype) then
            configure_javascript_debugging()
        elseif vim.tbl_contains(all_go_filetypes, filetype) then
            configure_go_debugging()
        else
            configure_general_debugging()
        end
    end,
    continue = function()
        filetype = project.get_project_language()

        local current_session = dap.session()
        if not current_session then
            M.setup(filetype)
        end

        if not current_session and filetype and #dap.configurations[filetype] > 0 then
            dap_ui.pick_if_many(
                dap.configurations[filetype],
                "Configuration: ",
                function(i) return i.name end,
                function(configuration)
                    if configuration then
                        M.run(configuration, { filetype = filetype })
                    end
                end
            )
        else
            dap.continue()
        end
    end
}

return M
