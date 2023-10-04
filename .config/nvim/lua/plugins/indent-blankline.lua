return {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
        indent = {
            char = require("utils.icons").Editor.IndentChar,
            tab_char = require("utils.icons").Editor.IndentTabChar,
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
