local icons = require 'ui.icons'
local buffers = require 'core.buffers'

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
        },
        exclude = {
            buftypes = buffers.special_buffer_types,
            filetypes = buffers.special_file_types,
        },
    },
    main = 'ibl',
    config = function(_, opts)
        require('ibl').setup(opts)
    end,
}
