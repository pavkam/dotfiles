return {
    'folke/tokyonight.nvim',
    version = '2.9.0', -- HACK: tree-sitter needs to be updated to 0.9.2 before updating this
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
