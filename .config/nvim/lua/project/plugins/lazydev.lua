return {
    {
        'folke/lazydev.nvim',
        ft = 'lua',
        opts = {
            library = {
                'luvit-meta/library',
            },
        },
    },
    { 'Bilal2453/luvit-meta', lazy = true }, -- optional `vim.uv` type information
}
