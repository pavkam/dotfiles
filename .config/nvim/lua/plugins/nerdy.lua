return {
    '2kabhishek/nerdy.nvim',
    cond = not ide.process.is_headless,
    dependencies = {
        'stevearc/dressing.nvim',
        'nvim-telescope/telescope.nvim',
    },
    cmd = 'Nerdy',
}
