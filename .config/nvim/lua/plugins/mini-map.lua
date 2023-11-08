return {
    'echasnovski/mini.map',
    event = 'User NormalFile',
    keys = {
        {
            '<leader>uP',
            function()
                require('utils').info 'Toggling mini map globally'
                require('mini.map').toggle()
            end,
            desc = 'Toggle global mini map',
        },
    },
    version = false,
    config = function()
        local icons = require 'utils.icons'
        local mini_map = require 'mini.map'

        mini_map.setup {
            integrations = {
                mini_map.gen_integration.builtin_search(),
                mini_map.gen_integration.gitsigns(),
                mini_map.gen_integration.diagnostic(),
            },
            symbols = {
                encode = mini_map.gen_encode_symbols.dot '4x2',
                scroll_line = icons.TUI.ScrollLine,
                scroll_view = icons.TUI.ScrollView,
            },
        }

        require('mini.map').toggle()
    end,
}
