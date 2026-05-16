return {
    'mfussenegger/nvim-dap',
    cond = #vim.api.nvim_list_uis() > 0,
    dependencies = {
        'rcarriga/nvim-dap-ui',
        'mxsdev/nvim-dap-vscode-js',
        'theHamsta/nvim-dap-virtual-text',
        'leoluz/nvim-dap-go',
        'mfussenegger/nvim-dap-python',
    },
    lazy = false,
    config = function()
        local icons = require 'icons'

        vim.api.nvim_set_hl(0, 'DapStoppedLine', { default = true, link = 'Visual' })

        local dap = require 'dap'
        dap.defaults.fallback.sign_priority = {
            breakpoint = 10,
            breakpoint_condition = 10,
            breakpoint_rejected = 10,
            log_point = 10,
            stopped = 20,
        }

        local signs = {
            DapStopped = { text = icons.fit(icons.Diagnostics.DAP.Stopped, 2), texthl = 'DiagnosticWarn', linehl = 'DapStoppedLine', numhl = 'DapStoppedLine' },
            DapBreakpoint = { text = icons.fit(icons.Diagnostics.DAP.Breakpoint, 2), texthl = 'DiagnosticInfo' },
            DapBreakpointRejected = { text = icons.fit(icons.Diagnostics.DAP.BreakpointRejected, 2), texthl = 'DiagnosticError' },
            DapBreakpointCondition = { text = icons.fit(icons.Diagnostics.DAP.BreakpointCondition, 2), texthl = 'DiagnosticInfo' },
            DapLogPoint = { text = icons.fit(icons.Diagnostics.DAP.LogPoint, 2), texthl = 'DiagnosticInfo' },
        }
        for name, def in pairs(signs) do
            vim.fn.sign_define(name, def)
        end

        -- DAP UI: auto-open/close on debug session
        local dapui = require 'dapui'
        dapui.setup({})
        dap.listeners.before.attach.dapui_config = function() dapui.open() end
        dap.listeners.before.launch.dapui_config = function() dapui.open() end
        dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
        dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

        -- Go adapter
        require('dap-go').setup()

        -- Python adapter
        local debugpy_path = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'packages', 'debugpy', 'venv', 'bin', 'python3')
        require('dap-python').setup(debugpy_path, { console = 'internalConsole' })

        -- JS/TS adapter
        require('dap-vscode-js').setup({
            node_path = 'node',
            debugger_path = vim.fn.stdpath('data') .. '/lazy/vscode-js-debug',
            adapters = { 'pwa-node', 'pwa-chrome', 'pwa-msedge', 'node-terminal', 'pwa-extensionHost' },
        })
    end,
}
