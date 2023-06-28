local M = {}

M.dap = {
    plugin = true,
    n = {
        ['<leader>db'] = {
            function ()
                require('dap').toggle_breakpoint();
            end,
            'Toggle breakpoint at line',
        },
        ['<F5>'] = {
            function ()
                require('dap').continue();
            end,
            'Continue debugging',
        },
        ['<F8>'] = {
            function ()
                require('dap').step_over();
            end,
            'Step over',
        },
        ['<F7>'] = {
            function ()
                require('dap').step_into();
            end,
            'Step into',
        },
        ['<F9>'] = {
            function ()
                require('dap').step_out();
            end,
            'Step out',
        },
    },
}

M.dap_go = {
    plugin = true,
    n = {
        ['<leader>td'] = {
            function ()
                require('dap-go').debug_test();
            end,
            'Debug go test',
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
        ['<A-Tab>'] = { '<C-O><C-W>w', 'Switch window' },
    },
    n = {
        ['<C-A>'] = { 'gggH<C-O>G', 'Select all' },
        ['<A-Tab>'] = { '<C-W>w', 'Switch window' },
    },
    v = {
        ['<C-A>'] = { '<C-C>gggH<C-O>G', 'Select all' },
        ['<A-Tab>'] = { '<C-O><C-W>w', 'Switch window' },
    },
}

return M
