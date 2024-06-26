return {
    'ray-x/go.nvim',
    cond = false,
    dependencies = {
        'ray-x/guihua.lua',
        'neovim/nvim-lspconfig',
        'nvim-treesitter/nvim-treesitter',
    },
    opts = {
        icons = false,
        dap_debug = false,
        test_runner = nil,
    },
    ft = {
        'go',
        'gomod',
    },
    build = ':lua require("go.install").update_all_sync()',
}
