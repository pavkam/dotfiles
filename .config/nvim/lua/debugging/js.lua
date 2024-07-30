local project = require 'project'

local bin_filetypes = { 'typescript', 'javascript' }
local jsx_filetypes = { 'typescriptreact', 'javascriptreact' }
local filetypes = vim.iter(bin_filetypes, jsx_filetypes):flatten():totable()

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
                project.get_js_bin_path(path, 'jest'),
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
return function(target)
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
    local launch_json = project.get_launch_json(target)
    if launch_json then
        dap_vscode.load_launchjs(launch_json, {
            ['pwa-node'] = filetypes,
            ['node'] = filetypes,
            ['chrome'] = filetypes,
            ['pwa-chrome'] = filetypes,
        })
    end
end
