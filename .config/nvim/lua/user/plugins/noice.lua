local utils = require "astronvim.utils"

return {
    'folke/noice.nvim',
    opts = function(_, opts)
        if not opts.lsp.progress then
            opts.lsp.progress = {}
        end

        opts.lsp.progress.enabled = false
        return opts
    end
}
