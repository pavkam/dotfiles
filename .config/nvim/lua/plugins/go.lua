return {
    "ray-x/go.nvim",
    dependencies = {
        "ray-x/guihua.lua",
        "neovim/nvim-lspconfig",
        "nvim-treesitter/nvim-treesitter",
        {
            "williamboman/mason.nvim",
            opts = {
                ensure_installed = {
                    "gomodifytags",
                    "impl",
                    "iferr",
                    "gorename",
                    "gomodifytags",
                    "gotests",
                    "gotestsum",
                    "fillstruct",
                    "fillswitch",
                    "ginkgo",
                    "richgo",
                    "govulncheck",
                    "goenum"
                }
            }
        }
    },
    opts = {
        icons = false,
        dap_debug = false,
        test_runner = nil,
    },
    ft = {
        "go",
        "gomod"
    },
    build = ':lua require("go.install").update_all_sync()',
}
