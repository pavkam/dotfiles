return {
    'kevinhwang91/nvim-bqf',
    cond = feature_level(1),
    ft = 'qf',
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
        },
    },
    config = function(_, opts)
        require('bqf').setup(opts)
    end,
}
