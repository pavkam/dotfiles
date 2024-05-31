return {
    'kevinhwang91/nvim-bqf',
    ft = 'qf',
    opts = {
        func_map = {
            open = 'o',
            openc = '<CR>',
            prevfile = '<C-p>',
            nextfile = '<C-n>',
            prevhist = '<',
            nexthist = '>',
            stoggledown = '<Tab>',
            stogglevm = '<Tab>',
            sclear = 'z<Tab>',
            pscrollup = '<C-b>',
            pscrolldown = '<C-f>',
            filter = 'zn',

            filterr = '',
            stoggleup = '',
            stogglebuf = '',
            drop = '',
            tabdrop = '',
            split = '<M-h>',
            vsplit = '<M-v>',
            tab = '',
            tabb = '',
            tabc = '',
            lastleave = '',
            fzffilter = '',
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
