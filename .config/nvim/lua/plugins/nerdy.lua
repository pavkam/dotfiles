return {
    '2kabhishek/nerdy.nvim',
    cond = not vim.headless,
    dependencies = {
        'stevearc/dressing.nvim',
        'nvim-telescope/telescope.nvim',
    },
    cmd = 'Nerdy',
}
