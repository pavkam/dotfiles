local icons = require 'ui.icons'

return {
    'lukas-reineke/indent-blankline.nvim',
    cond = not vim.headless,
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
            buftypes = vim.buf.special_buffer_types,
            filetypes = vim.buf.special_file_types,
        },
    },
    main = 'ibl',
    config = function(_, opts)
        require('ibl').setup(opts)
    end,
}
