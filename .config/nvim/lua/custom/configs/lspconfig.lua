local on_attach = require('plugins.configs.lspconfig').on_attach
local capabilities = require('plugins.configs.lspconfig').capabilities

local lspconfig = require('lspconfig')
local util = require 'lspconfig/util'

lspconfig.gopls.setup {
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
        gopls = {
            completeUnimported = true,
            usePlaceholders = true,
            analyses = {
                unusedparams = true,
            },
            staticcheck = true,
        },
    },
}

lspconfig.bashls.setup {
    on_attach = on_attach,
    capabilities = capabilities,
    setting = {
        bashIde = {
            globPattern = "*@(.sh|.inc|.bash|.command)"
        }
    }
}

lspconfig.tsserver.setup {
    on_attach = on_attach,
    capabilities = capabilities,
}

lspconfig.prismals.setup{
    on_attach = on_attach,
    capabilities = capabilities,
}
