local utils = require "utils"

return {
    {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
            utils.list_insert_unique(opts.ensure_installed, {
                "dockerfile",
            })
        end,
    },
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                dockerls = {},
                docker_compose_language_service = {},
            },
        },
    },
    {
        "nvimtools/none-ls.nvim",
        dependancies = {
            {
                "jay-babu/mason-null-ls.nvim",
                opts = function(_, opts) opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "hadolint") end,
            }
        }
    },
}
