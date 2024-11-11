return {
    'folke/lazydev.nvim',
    cond = not vim.headless,
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
