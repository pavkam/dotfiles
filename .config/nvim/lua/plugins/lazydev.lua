return {
    'folke/lazydev.nvim',
    cond = #vim.api.nvim_list_uis() > 0,
    dependencies = {
        'Bilal2453/luvit-meta',
    },
    ft = 'lua',
    opts = {
        library = {
            'luvit-meta/library',
        },
    },
}
