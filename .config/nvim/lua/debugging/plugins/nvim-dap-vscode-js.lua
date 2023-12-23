return {
    'mxsdev/nvim-dap-vscode-js',
    dependencies = {
        {
            'microsoft/vscode-js-debug',
            build = 'npm ci --legacy-peer-deps && npx gulp vsDebugServerBundle && (rm -rf out || true) && mv dist out',
        },
        'mfussenegger/nvim-dap',
    },
    config = function()
        local function get_js_debug()
            local path = vim.fn.stdpath 'data'
            return path .. '/lazy/vscode-js-debug'
        end

        ---@diagnostic disable-next-line: missing-fields
        require('dap-vscode-js').setup {
            node_path = 'node',
            debugger_path = get_js_debug(),
            adapters = { 'pwa-node', 'pwa-chrome', 'pwa-msedge', 'node-terminal', 'pwa-extensionHost' },
        }
    end,
}
