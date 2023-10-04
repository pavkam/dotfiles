return {
    "lvimuser/lsp-inlayhints.nvim",
    opts = {},
    init = function()
        local lsp = require "utils.lsp"

        lsp.on_attach(
            function(client, buffer)
                if client.server_capabilities.inlayHintProvider then
                    local inlayhints = require "lsp-inlayhints"

                    inlayhints.on_attach(client, buffer)

                    vim.keymap.set("n", "<leader>uH", inlayhints.toggle, { desc = "Toggle Inlay Hints", buffer = buffer })
                end
            end
        )
    end,
}
