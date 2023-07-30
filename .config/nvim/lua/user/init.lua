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
    lsp = {
        config = {
            gopls = {
                completeUnimported = true,
                usePlaceholders = true,
                analyses = {
                    unusedparams = true,
                },
                staticcheck = true,
            },
            bashls = {
                bashIde = {
                    globPattern = "*@(.sh|.inc|.bash|.command)"
                },
            },
        },
    },
}
