return {
    {
        'mxsdev/nvim-dap-vscode-js',
        ft = { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' },
        dependancies = {
            'mfussenegger/nvim-dap',
            'microsoft/vscode-js-debug'
        },
        config = function()
            local function get_js_debug()
                local path = vim.fn.stdpath 'data'
                return path .. '/lazy/vscode-js-debug'
            end

            require('dap-vscode-js').setup {
                node_path = 'node',
                debugger_path = get_js_debug(),
                adapters = {'pwa-node', 'pwa-chrome', 'pwa-msedge', 'node-terminal', 'pwa-extensionHost'}
            }

            for _, language in ipairs {'typescript', 'javascript'} do
                require('dap').configurations[language] = {{
                    type = 'pwa-node',
                    request = 'launch',
                    name = 'Launch file',
                    program = '${file}',
                    cwd = '${workspaceFolder}'
                }, {
                    type = 'pwa-node',
                    request = 'attach',
                    name = 'Attach',
                    processId = require('dap.utils').pick_process,
                    cwd = '${workspaceFolder}'
                }, {
                    type = 'pwa-node',
                    request = 'launch',
                    name = 'Debug Jest Tests',
                    -- trace = true, -- include debugger info
                    runtimeExecutable = 'node',
                    runtimeArgs = {'./node_modules/jest/bin/jest.js', '--runInBand'},
                    rootPath = '${workspaceFolder}',
                    cwd = '${workspaceFolder}',
                    console = 'integratedTerminal',
                    internalConsoleOptions = 'neverOpen'
                }, {
                    type = 'pwa-chrome',
                    name = 'Attach - Remote Debugging',
                    request = 'attach',
                    program = '${file}',
                    cwd = vim.fn.getcwd(),
                    sourceMaps = true,
                    protocol = 'inspector',
                    port = 9222, -- Start Chrome google-chrome --remote-debugging-port=9222
                    webRoot = '${workspaceFolder}'
                }, {
                    type = 'pwa-chrome',
                    name = 'Launch Chrome',
                    request = 'launch',
                    url = 'http://localhost:5173', -- This is for Vite. Change it to the framework you use
                    webRoot = '${workspaceFolder}',
                    userDataDir = '${workspaceFolder}/.vscode/vscode-chrome-debug-userdatadir'
                }}
            end

            for _, language in ipairs {'typescriptreact', 'javascriptreact'} do
                require('dap').configurations[language] = {{
                    type = 'pwa-chrome',
                    name = 'Attach - Remote Debugging',
                    request = 'attach',
                    program = '${file}',
                    cwd = vim.fn.getcwd(),
                    sourceMaps = true,
                    protocol = 'inspector',
                    port = 9222, -- Start Chrome google-chrome --remote-debugging-port=9222
                    webRoot = '${workspaceFolder}'
                }, {
                    type = 'pwa-chrome',
                    name = 'Launch Chrome',
                    request = 'launch',
                    url = 'http://localhost:5173', -- This is for Vite. Change it to the framework you use
                    webRoot = '${workspaceFolder}',
                    userDataDir = '${workspaceFolder}/.vscode/vscode-chrome-debug-userdatadir'
                }}
            end
	    end
    },
    {
        'microsoft/vscode-js-debug',
        lazy = false,
        build = 'npm ci --legacy-peer-deps && npx gulp vsDebugServerBundle && (rm out || true) && mv dist out'
    },
}
