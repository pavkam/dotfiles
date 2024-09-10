local icons = require 'ui.icons'

return {
    'stevearc/dressing.nvim',
    dependencies = {
        'MunifTanjim/nui.nvim',
        'nvim-lua/plenary.nvim',
        'nvim-telescope/telescope.nvim',
    },
    cond = not vim.headless,
    opts = {
        input = {
            default_prompt = icons.TUI.PromptPrefix,
            trim_prompt = true,
            border = vim.g.border_style,
            relative = 'editor',
            title_pos = 'left',
        },
        select = {
            backend = { 'telescope', 'builtin' },
            trim_prompt = true,
            builtin = {
                show_numbers = false,
                border = vim.g.border_style,
                relative = 'editor',
            },
        },
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
