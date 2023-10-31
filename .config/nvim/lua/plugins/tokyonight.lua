return {
    'folke/tokyonight.nvim',
    opts = { style = 'moon' },
    config = function(opts)
        require('tokyonight').load(opts)
    end,
}
