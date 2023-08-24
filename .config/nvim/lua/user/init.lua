return {
    colorscheme = 'catppuccin',
    diagnostics = {
        virtual_text = true,
        underline = true,
    },
    formatting = {
      format_on_save = {
        enabled = true,
      },
    },
    lazy = {
        defaults = { lazy = true },
        performance = {
            rtp = {
                disabled_plugins = { 'tohtml', 'gzip', 'matchit', 'zipPlugin', 'netrwPlugin', 'tarPlugin' },
            },
        },
    },
    mappings = function(maps)
        print(maps)
    end,
    lsp = {
        config = {
            gopls = {
                completeUnimported = true,
                usePlaceholders = true,
                analyses = {
                    unusedparams = true,
                },
                staticcheck = false,
                hints = {
                    assignVariableTypes = true,
                    compositeLiteralFields = true,
                    constantValues = true,
                    functionTypeParameters = true,
                    parameterNames = true,
                    rangeVariableTypes = true,
                },
            },
            bashls = {
                bashIde = {
                    globPattern = "*@(.sh|.inc|.bash|.command)"
                },
            },
            tsserver = {
                settings = {
                    typescript = {
                        inlayHints = {
                            includeInlayParameterNameHints = 'all',
                            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                            includeInlayFunctionParameterTypeHints = true,
                            includeInlayVariableTypeHints = true,
                            includeInlayVariableTypeHintsWhenTypeMatchesName = false,
                            includeInlayPropertyDeclarationTypeHints = true,
                            includeInlayFunctionLikeReturnTypeHints = true,
                            includeInlayEnumMemberValueHints = true,
                        }
                    },
                    javascript = {
                        inlayHints = {
                            includeInlayParameterNameHints = 'all',
                            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                            includeInlayFunctionParameterTypeHints = true,
                            includeInlayVariableTypeHints = true,
                            includeInlayVariableTypeHintsWhenTypeMatchesName = false,
                            includeInlayPropertyDeclarationTypeHints = true,
                            includeInlayFunctionLikeReturnTypeHints = true,
                            includeInlayEnumMemberValueHints = true,
                        },
                    },
                },
            },
        },
    },
}
