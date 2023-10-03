local utils = require "utils"

return {
    {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
            utils.list_insert_unique(opts.ensure_installed, {
                "json",
                "jsdoc",
                "jsonc"
            })
        end,
    },
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                jsonls = {}
            },
        },
    },
    {
        "nvimtools/none-ls.nvim",
        opts = function(_, opts)
            local nls = require("null-ls")
            utils.list_insert_unique(opts.sources, {
                nls.builtins.formatting.prettier,
            })
        end,
    },
}
