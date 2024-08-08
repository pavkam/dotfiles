return {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
        preset = 'helix',
        plugins = { spelling = false },
        triggers = {
            { '<auto>', mode = 'nisotc' },
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
