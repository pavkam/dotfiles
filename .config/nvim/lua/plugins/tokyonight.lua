return {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    ---@type tokyonight.Config
    opts = {
        style = 'moon',
        on_colors = function(colors)
            colors.border = colors.blue
        end,
        on_highlights = function(hl, color_scheme)
            hl.DiagnosticUnnecessary = { fg = color_scheme.fg_dark }
        end,
        cache = false,
    },
    config = function(_, opts)
        require('tokyonight').setup(opts)
        vim.cmd.colorscheme 'tokyonight'
    end,
}
