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
        end
    },
    {
        'microsoft/vscode-js-debug',
        lazy = false,
        build = 'npm ci --legacy-peer-deps && npx gulp vsDebugServerBundle && (rm out || true) && mv dist out'
    },
}
