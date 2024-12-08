return {
    'folke/lazydev.nvim',
    cond = not ide.process.is_headless,
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
