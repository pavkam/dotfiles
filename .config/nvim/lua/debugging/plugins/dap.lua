return {
    'mfussenegger/nvim-dap',
    dependencies = {
        'rcarriga/nvim-dap-ui',
        'mxsdev/nvim-dap-vscode-js',
        'theHamsta/nvim-dap-virtual-text',
        'rcarriga/cmp-dap',
        'leoluz/nvim-dap-go',
        'mfussenegger/nvim-dap-python',
    },
    keys = {
        {
            '<leader>dB',
            function()
                require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
            end,
            desc = 'Breakpoint condition',
        },
        {
            '<leader>db',
            function()
                require('dap').toggle_breakpoint()
            end,
            desc = 'Toggle breakpoint',
        },
        {
            '<leader>dc',
            function()
                require('debugging').continue()
            end,
            desc = 'Continue',
        },
        {
            '<leader>dC',
            function()
                require('dap').run_to_cursor()
            end,
            desc = 'Run to cursor',
        },
        {
            '<leader>dg',
            function()
                require('dap').goto_()
            end,
            desc = 'Go to line (no execute)',
        },
        {
            '<leader>di',
            function()
                require('dap').step_into()
            end,
            desc = 'Step into',
        },
        {
            '<leader>dj',
            function()
                require('dap').down()
            end,
            desc = 'Down',
        },
        {
            '<leader>dk',
            function()
                require('dap').up()
            end,
            desc = 'Up',
        },
        {
            '<leader>dl',
            function()
                require('dap').run_last()
            end,
            desc = 'Run last',
        },
        {
            '<leader>dO',
            function()
                require('dap').step_out()
            end,
            desc = 'Step out',
        },
        {
            '<leader>do',
            function()
                require('dap').step_over()
            end,
            desc = 'Step over',
        },
        {
            '<leader>dP',
            function()
                require('dap').pause()
            end,
            desc = 'Pause',
        },
        {
            '<leader>dR',
            function()
                require('dap').repl.toggle()
            end,
            desc = 'Toggle REPL',
        },
        {
            '<leader>ds',
            function()
                require('dap').session()
            end,
            desc = 'Session',
        },
        {
            '<leader>dQ',
            function()
                require('dap').terminate()
            end,
            desc = 'Terminate',
        },
        {
            '<leader>dw',
            function()
                require('dap.ui.widgets').hover()
            end,
            desc = 'Inspect symbol',
        },
    },
    config = function()
        local icons = require 'ui.icons'

        vim.api.nvim_set_hl(0, 'DapStoppedLine', { default = true, link = 'Visual' })

        local signs = {
            {
                name = 'DapStopped',
                text = icons.Diagnostics.DAP.Stopped .. ' ',
                texthl = 'DiagnosticWarn',
                linehl = 'DapStoppedLine',
                numhl = 'DapStoppedLine',
            },
            { name = 'DapBreakpoint', text = icons.Diagnostics.DAP.Breakpoint .. ' ', texthl = 'DiagnosticInfo' },
            {
                name = 'DapBreakpointRejected',
                text = icons.Diagnostics.DAP.BreakpointRejected .. ' ',
                texthl = 'DiagnosticError',
            },
            {
                name = 'DapBreakpointCondition',
                text = icons.Diagnostics.DAP.BreakpointCondition .. ' ',
                texthl = 'DiagnosticInfo',
            },
            { name = 'DapLogPoint', text = icons.Diagnostics.DAP.LogPoint, texthl = 'DiagnosticInfo' },
        }

        for _, sign in ipairs(signs) do
            vim.fn.sign_define(sign.name, sign)
        end
    end,
}
