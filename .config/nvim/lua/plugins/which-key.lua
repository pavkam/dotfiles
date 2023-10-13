local icons = require("utils.icons")

return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        plugins = { spelling = true },
        icons = {
            group = ""
        },
        defaults = {
            mode = { "n", "v" },
            ["g"] = { name = icons.ui.Next .." Go-to" },
            ["]"] = { name = icons.ui.Next .." Next" },
            ["["] = { name = icons.ui.Prev .." Previous" },
            ["<leader>b"] = { name = icons.ui.Buffers .." Buffers" },
            ["<leader>g"] = { name = icons.ui.Git .." Git" },
            ["<leader>u"] = { name = icons.ui.UI .." Settings" },
            ["<leader>q"] = { name = icons.ui.Fix .." Quick-Fix" },
            ["<leader>f"] = { name = icons.ui.Search .." Search" },
            ["<leader>?"] = { name = icons.ui.Help .." Help" },
            ["<leader>d"] = { name = icons.ui.Debugger .. " Debugger" },
            ["<leader>s"] = { name = icons.ui.LSP .." Source" },
        },
    },
    config = function(_, opts)
        local wk = require("which-key")
        wk.setup(opts)
        wk.register(opts.defaults)
    end,
}
