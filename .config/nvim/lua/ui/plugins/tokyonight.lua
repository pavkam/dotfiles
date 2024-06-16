return {
    'folke/tokyonight.nvim',
    cond = false,
    opts = {
        style = 'moon',
        on_colors = function(colors)
            colors.border = colors.blue
        end,
    },
    config = function(_, opts)
        require('tokyonight').load(opts)
    end,
}
