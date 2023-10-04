return {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    config = function(_, opts)
        local path = require("mason-registry").get_package("debugpy"):get_install_path() .. "/venv/bin/python"
        require("dap-python").setup(path, opts)
    end,
}
