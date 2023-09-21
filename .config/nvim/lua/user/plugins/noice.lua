local utils = require "astronvim.utils"

return {
    'folke/noice.nvim',
    --enabled = false,
    opts = function(_, opts)
        opts.presets = opts.presets or {}
        opts.presets.lsp_doc_border = true

        return opts
    end
}
