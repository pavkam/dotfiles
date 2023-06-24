local M = {}

M.dap = {
    plugin = true,
    n = {
        ['<leader>db'] = {
            '<cmd> DapToggleBreakpoint <CR>',
            'Toggle breakpoint at line',
        },
        ['<leader>dus'] = {
            function ()
                local widgets = require('dap.ui.widgets');
                local sidebar = widgets.sidebar(widgets.scopes);
                sidebar.open();
            end,
            'Open debugging sidebar',
        },
    },
}

M.dap_go = {
    plugin = true,
    n = {
        ['<leader>dgt'] = {
            function ()
                require('dap-go').debug_test();
            end,
            'Debug go test',
        },
        ['<leader>dgl'] = {
            function ()
                require('dap-go').debug_last();
            end,
            'Debug last go test',
        },
    },
}

M.neotest = {
    plugin = true,
    n = {
        ['<leader>tf'] = {
            function ()
                vim.cmd('w')
                require('neotest').run.run(vim.fn.expand('%'))
            end,
            'Test current file',
        },
    },
}

M.disabled = {
    n = {
        ['j'] = '',
        ['k'] = '',
        ['<<'] = '',
        ['>>'] = '',
    },
    i = {
        ['<A-Tab>'] = '',
        ['<C-h>'] = '',
        ['<C-l>'] = '',
        ['<C-j>'] = '',
        ['<C-k>'] = '',
    },
}

M.general = {
    i = {
        ['<S-Tab>'] = { '<C-d>', 'Left tab' },
        ['<C-x>'] = { '<C-O>dd', 'Delete current line' },
        ['<C-z>'] = { '<C-O>u', 'Undo previous change' },
        ['<C-y>'] = { '<C-O>r', 'Redo previous change' },
        ['<C-A>'] = { '<C-O>gg<C-O>gH<C-O>G', 'Select all' },
        ['<leader><Tab>'] = { '<C-O><C-W>w', 'Switch window' },
    },
    n = {
        ['<C-A>'] = { 'gggH<C-O>G', 'Select all' },
        ['<C-Tab>'] = { '<C-W>w', 'Switch window' },
    },
    v = {
        ['<C-A>'] = { '<C-C>gggH<C-O>G', 'Select all' },
        ['<C-Tab>'] = { '<C-O><C-W>w', 'Switch window' },
    },
}

return M
