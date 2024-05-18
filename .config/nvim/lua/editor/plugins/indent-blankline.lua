local icons = require 'ui.icons'
local utils = require 'core.utils'

return {
    'lukas-reineke/indent-blankline.nvim',
    event = 'User NormalFile',
    opts = {
        indent = {
            char = icons.TUI.IndentLevel,
            tab_char = icons.TUI.IndentLevel,
        },
        scope = {
            enabled = true,
            show_start = true,
            show_end = true,
        },
        exclude = {
            buftypes = utils.special_buffer_types,
            filetypes = utils.special_file_types,
        },
    },
    main = 'ibl',
    config = function(_, opts)
        require('ibl').setup(opts)
    end,
}
