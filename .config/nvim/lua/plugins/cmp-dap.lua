return {
    "rcarriga/cmp-dap",
    dependencies = {
        "nvim-cmp"
    },
    config = function()
        require("cmp").setup.filetype({ "dap-repl", "dapui_watches", "dapui_hover" }, {
            sources = {
                { name = "dap" },
            },
        })
    end,
}
