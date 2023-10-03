local utils = require "utils"

return {
    {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
            utils.list_insert_unique(opts.ensure_installed, {
                "proto",
            })
        end,
    },
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                bufls = {}
            },
        },
    },
    {
        "nvimtools/none-ls.nvim",
        dependancies = {
            {
                "jay-babu/mason-null-ls.nvim",
                opts = function(_, opts) opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "buf") end,
            }
        }
    },
}
