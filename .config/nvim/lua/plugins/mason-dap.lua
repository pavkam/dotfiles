return {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = {
        "williamboman/mason.nvim",
        "mfussenegger/nvim-dap",
    },
    cmd = {
        "DapInstall",
        "DapUninstall"
    },
    opts = {
        automatic_installation = true,
    },
    opts = {
        ensure_installed = {
            "bash",
            "coreclr",
            "python",
            "js",
            "delve"
        }
    }
}
