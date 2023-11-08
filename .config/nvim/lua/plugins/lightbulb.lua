local icons = require 'utils.icons'

return {
    'kosayoda/nvim-lightbulb',
    event = 'LspAttach',
    opts = {
        sign = {
            enabled = false,
            text = icons.Diagnostics.Action,
        },
        virtual_text = {
            enabled = true,
            text = icons.Diagnostics.Action,
        },
        float = {
            text = icons.Diagnostics.Action,
        },
        autocmd = {
            enabled = true,
        },
    },
}
