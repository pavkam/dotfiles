return {
    'folke/tokyonight.nvim',
    enabled = feature_level(1),
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
