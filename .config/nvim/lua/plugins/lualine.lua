return {
    'nvim-lualine/lualine.nvim',
    cond = not ide.process.is_headless,
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    },
    event = 'UIEnter',
    opts = function()
        local lualine_sections = require 'lualine-sections'

        return {
            options = {
                globalstatus = true,
                theme = 'auto',
                disabled_filetypes = { winbar = { 'dap-repl' } },
            },
            sections = lualine_sections.status_line,
            tabline = lualine_sections.tab_line,
            winbar = lualine_sections.win_bar,
            inactive_winbar = lualine_sections.inactive_win_bar,
            extensions = lualine_sections.extensions,
        }
    end,
}
