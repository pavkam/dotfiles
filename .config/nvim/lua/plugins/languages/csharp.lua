local utils = require "utils"

return {
    {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
            utils.list_insert_unique(opts.ensure_installed, {
                "c_sharp",
            })
        end,
    },
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                csharp_ls = {},
            },
        },
    },
    {
        "mfussenegger/nvim-dap",
        dependancies = {
            {
                "jay-babu/mason-nvim-dap.nvim",
                opts = function(_, opts) opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "coreclr") end,
            },
        }
    },
    {
        "nvimtools/none-ls.nvim",
        dependancies = {
            {
                "jay-babu/mason-null-ls.nvim",
                opts = function(_, opts) opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "csharpier") end,
            }
        }
    },
}
