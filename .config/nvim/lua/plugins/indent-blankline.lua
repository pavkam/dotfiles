local icons = require "utils.icons"
return {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
        indent = {
            char = icons.TUI.IndentLevel,
            tab_char = icons.TUI.IndentLevel,
        },
        scope = {
            enabled = false
        },
        exclude = {
            filetypes = {
                "help",
                "alpha",
                "dashboard",
                "neo-tree",
                "Trouble",
                "lazy",
                "mason",
                "notify",
                "toggleterm",
                "lazyterm",
            },
        },
    },
    main = "ibl",
}