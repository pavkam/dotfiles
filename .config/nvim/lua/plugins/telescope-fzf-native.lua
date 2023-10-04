return {
    "nvim-telescope/telescope-fzf-native.nvim",
    enabled = vim.fn.executable "make" == 1,
    build = "make"
}
