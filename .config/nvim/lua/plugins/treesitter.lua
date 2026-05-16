return {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
        ensure_installed = {
            'bash', 'c', 'css', 'dockerfile', 'go', 'gomod', 'gosum',
            'html', 'javascript', 'json', 'jsonc', 'lua', 'luadoc',
            'markdown', 'markdown_inline', 'python', 'regex', 'rust',
            'toml', 'tsx', 'typescript', 'vim', 'vimdoc', 'yaml',
        },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
    },
}
