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
            { '<leader>', mode = 'v' },
            { 'd', mode = 'v' },
        },
        icons = {
            group = '',
        },
    },
}
