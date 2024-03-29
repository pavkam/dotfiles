local icons = require 'ui.icons'

return {
    'stevearc/dressing.nvim',
    opts = {
        input = { default_prompt = icons.TUI.PromptPrefix },
        select = { backend = { 'telescope', 'builtin' } },
    },
    init = function()
        local lazy = require 'lazy'

        ---@diagnostic disable-next-line: duplicate-set-field
        vim.ui.select = function(...)
            lazy.load { plugins = { 'dressing.nvim' } }
            return vim.ui.select(...)
        end

        ---@diagnostic disable-next-line: duplicate-set-field
        vim.ui.input = function(...)
            lazy.load { plugins = { 'dressing.nvim' } }
            return vim.ui.input(...)
        end
    end,
}
