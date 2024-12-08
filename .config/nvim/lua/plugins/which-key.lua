return {
    'folke/which-key.nvim',
    cond = not ide.process.is_headless,
    event = 'VeryLazy',
    opts = {
        preset = 'helix',
        plugins = { spelling = false },
        triggers = {
            { '<auto>', mode = 'nisoc' },
            { 'a', mode = 'v' },
            { 'i', mode = 'v' },
            { 'g', mode = 'v' },
            { 'z', mode = 'v' },
            { '<leader>', mode = 'v' },
        },
        icons = {
            group = '',
        },
    },
}
