local utils = require "utils"

return {
    {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
            utils.list_insert_unique(opts.ensure_installed, {
                "javascript",
                "typescript",
                "tsx"
            })
        end,
    },
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                tsserver = {},
            },
        },
    },
    {
        "nvimtools/none-ls.nvim",
    },
    {
        "mfussenegger/nvim-dap",
        dependancies = {
            {
                "jay-babu/mason-nvim-dap.nvim",
                opts = function(_, opts) opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "js") end,
            },
        }
    },
    {
        "vuki656/package-info.nvim",
        dependencies = { "MunifTanjim/nui.nvim" },
        opts = {},
        event = "BufRead package.json",
    },
}
