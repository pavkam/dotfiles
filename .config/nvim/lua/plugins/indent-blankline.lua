local icons = require 'utils.icons'
local utils = require 'utils'

return {
    'lukas-reineke/indent-blankline.nvim',
    enabled = feature_level(2),
    event = 'User NormalFile',
    opts = {
        indent = {
            char = icons.TUI.IndentLevel,
            tab_char = icons.TUI.IndentLevel,
        },
        scope = {
            enabled = true,
        },
        exclude = {
            buftypes = utils.special_buffer_types,
            filetypes = utils.special_file_types,
        },
    },
    main = 'ibl',
}
