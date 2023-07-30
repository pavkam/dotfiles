local utils = require 'astronvim.utils'
return {
    'jay-babu/mason-null-ls.nvim',
    opts = function(_, opts)
        opts.ensure_installed =
            utils.list_insert_unique(opts.ensure_installed, { 'golines', 'golangci_lint', 'staticcheck', 'goimports_reviser' })
    end
}
