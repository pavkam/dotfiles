return {
    {
        "folke/tokyonight.nvim",
        lazy = true,
        opts = { style = "moon" },
    },
    {
        "catppuccin/nvim",
        lazy = true,
        name = "catppuccin",
        opts = {
            integrations = {
                alpha = true,
                cmp = true,
                flash = true,
                gitsigns = true,
                illuminate = true, -- TODO: not needed
                indent_blankline = { enabled = true },
                lsp_trouble = true,-- TODO: not needed
                mason = true,
                mini = true,
                native_lsp = {
                    enabled = true,
                    underlines = {
                        errors = { "undercurl" },
                        hints = { "undercurl" },
                        warnings = { "undercurl" },
                        information = { "undercurl" },
                    },
                },
                navic = { enabled = true, custom_bg = "lualine" }, -- TODO: not needed
                neotest = true,
                noice = true,
                notify = true,
                neotree = true,
                semantic_tokens = true,
                telescope = true,
                treesitter = true,
                which_key = true,
            },
        },
    },
}
