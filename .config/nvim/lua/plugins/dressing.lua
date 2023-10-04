return {
    "stevearc/dressing.nvim",
    opts = {
        input = { default_prompt = require("utils.icons").ui.PromptPrefix .. " " },
        select = { backend = { "telescope", "builtin" } },
    },
    init = function()
        vim.ui.select = function(...)
            require("lazy").load({ plugins = { "dressing.nvim" } })
            return vim.ui.select(...)
        end
        vim.ui.input = function(...)
            require("lazy").load({ plugins = { "dressing.nvim" } })
            return vim.ui.input(...)
        end
    end,
}
