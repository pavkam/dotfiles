return {
    "mxsdev/nvim-dap-vscode-js",
    ft = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
    event = "LspAttach",
    dependencies = {
        "mfussenegger/nvim-dap",
        "microsoft/vscode-js-debug"
    },
    config = function()
        local function get_js_debug()
            local path = vim.fn.stdpath "data"
            return path .. "/lazy/vscode-js-debug"
        end

        require("dap-vscode-js").setup {
            node_path = "node",
            debugger_path = get_js_debug(),
            adapters = {"pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost"}
        }
    end
}
