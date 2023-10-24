return {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    opts = {
        func_map = {
            split = '\\',
            vsplit = '|',
            tab = '',
            tabb = '',
            tabc = '',
            lastleave = '',
            fzffilter = '',
            filterr = '',
            filter = '',
            ptoggleauto = '',
            ptoggleitem = '',
            ptogglemode = '',
            pscrollorig = '',
        }
    },
    config = function(_, opts)
        require("bqf").setup(opts)
    end
}
