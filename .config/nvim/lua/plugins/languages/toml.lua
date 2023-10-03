local utils = require "utils"

return {
    {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
            utils.list_insert_unique(opts.ensure_installed, {
                "toml",
            })
        end,
    },
    {
        "mason.nvim",
        opts = function(_, opts)
            opts.ensure_installed = opts.ensure_installed or {}
            utils.list_insert_unique(opts.ensure_installed, {
                "taplo",
            })
        end,
    },
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                taplo = {}
            },
        },
    },
}
