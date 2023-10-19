local icons = require "utils.icons"
local ui = require "utils.ui"

return {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
        indent = {
            char = icons.TUI.IndentLevel,
            tab_char = icons.TUI.IndentLevel,
        },
        scope = {
            enabled = true
        },
        exclude = {
            buftypes = ui.special_buffer_types,
            filetypes = ui.special_file_types,
        },
    },
    main = "ibl",
}
