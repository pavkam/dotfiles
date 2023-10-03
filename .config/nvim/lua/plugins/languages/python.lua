local utils = require "utils"

return {
    {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
            utils.list_insert_unique(opts.ensure_installed, {
                "python",
            })
        end,
    },
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                pyright = {},
                ruff_lsp = {},
            },
        },
    },
    {
        "mfussenegger/nvim-dap",
        dependancies = {
            {
                "jay-babu/mason-nvim-dap.nvim",
                opts = function(_, opts) opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "python") end,
            },
            {
                "mfussenegger/nvim-dap-python",
                ft = "python",
                config = function(_, opts)
                    local path = require("mason-registry").get_package("debugpy"):get_install_path() .. "/venv/bin/python"
                    require("dap-python").setup(path, opts)
                end,
            },
        }
    },
    {
        "nvimtools/none-ls.nvim",
        dependancies = {
            {
                "jay-babu/mason-null-ls.nvim",
                opts = function(_, opts) opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, { "black", "isort" }) end,
            }
        }
    },
}
