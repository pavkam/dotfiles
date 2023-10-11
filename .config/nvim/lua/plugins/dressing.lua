local icons = require "utils.icons"

return {
    "stevearc/dressing.nvim",
    opts = {
        input = { default_prompt = icons.TUI.PromptPrefix },
        select = { backend = { "telescope", "builtin" } },
    },
    init = function()
        local lazy = require "lazy"

        vim.ui.select = function(...)
            lazy.load({ plugins = { "dressing.nvim" } })
            return vim.ui.select(...)
        end

        vim.ui.input = function(...)
            lazy.load({ plugins = { "dressing.nvim" } })
            return vim.ui.input(...)
        end
    end,
}
