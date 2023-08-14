local utils = require 'astronvim.utils'
local get_icon = utils.get_icon

test = { desc = get_icon('DiagnosticWarn', 1, true) .. 'Testing' }

function continue_debug()
    if vim.fn.filereadable('.vscode/launch.json') then
        local jsl = { "typescript", "javascript", "typescriptreact", "javascriptreact" }
        require('dap.ext.vscode').load_launchjs(nil, {
            ['pwa-node'] = jsl,
            ['node'] = jsl,
            ['chrome'] = jsl,
            ['pwa-chrome'] = jsl
        })
    end

    require('dap').continue();
end

return {
    n = {
        ['<leader>z'] = test,
        ['<leader>zs'] = {
            function ()
                require('neotest').summary.toggle()
            end,
            desc = 'Toggle summary view',
        },
        ['<leader>zo'] = {
            function ()
                require('neotest').output.open()
            end,
            desc = 'Show test output',
        },
        ['<leader>zw'] = {
            function ()
                require('neotest').watch.toggle()
            end,
            desc = 'Toggle test watching',
        },
        ['<leader>zf'] = {
            function ()
                require('neotest').run.run(vim.fn.expand('%'))
            end,
            desc = 'Run all tests in buffer',
        },
        ['<leader>zr'] = {
            function ()
                require('neotest').run.run()
            end,
            desc = 'Run nearest test in buffer',
        },
        ['<leader>zd'] = {
            function ()
                if vim.bo.filetype == "go" then
                    require('dap-go').debug_test()
                else
                    require("neotest").run.run({strategy = "dap"})
                end
            end,
            desc = 'Debug nearest test in buffer',
        },
        ['<F5>'] = {
            continue_debug,
            desc = 'Debugger: Start',
        },
        ['<leader>dc'] = {
            continue_debug,
            desc = 'Start/Continue (F5)',
        },
        ['<C-`>'] = {
            function() require("telescope.builtin").keymaps() end,
            desc = 'Keymaps',
        },
        ['<A-Tab>'] = { '<C-W>w', desc = 'Switch window' },
        ['<A-Left>'] = { '<C-w>h', desc = 'Window left' },
        ['<A-Right>'] = { '<C-w>l', desc = 'Window right' },
        ['<A-Down>'] = { '<C-w>j', desc = 'Window down' },
        ['<A-Up>'] = { '<C-w>k', desc = 'Window up' },

        ['<A-S-Right>'] = { '<cmd> bnext <cr>', desc = 'Buffer next' },
        ['<A-S-Left>'] = { '<cmd> bprev <cr>', desc = 'Buffer previous' },
    },
    i = {
        ['<A-Tab>'] = { '<C-W>w', desc = 'Switch window' },
        ['<A-Left>'] = { '<C-w>h', desc = 'Window left' },
        ['<A-Right>'] = { '<C-w>l', desc = 'Window right' },
        ['<A-Down>'] = { '<C-w>j', desc = 'Window down' },
        ['<A-Up>'] = { '<C-w>k', desc = 'Window up' },

        ['<A-S-Right>'] = { '<cmd> bnext <cr>', desc = 'Buffer next' },
        ['<A-S-Left>'] = { '<cmd> bprev <cr>', desc = 'Buffer previous' },
    },
    v = {
        ['<A-Tab>'] = { '<C-W>w', desc = 'Switch window' },
        ['<A-Left>'] = { '<C-w>h', desc = 'Window left' },
        ['<A-Right>'] = { '<C-w>l', desc = 'Window right' },
        ['<A-Down>'] = { '<C-w>j', desc = 'Window down' },
        ['<A-Up>'] = { '<C-w>k', desc = 'Window up' },

        ['<A-S-Right>'] = { '<cmd> bnext <cr>', desc = 'Buffer next' },
        ['<A-S-Left>'] = { '<cmd> bprev <cr>', desc = 'Buffer previous' },
    },
    t = {
        ['<esc><esc>'] = { '<C-\\><C-n>', desc = 'die' },

        ['<A-Tab>'] = { '<C-W>w', desc = 'Switch window' },
        ['<A-Left>'] = { '<C-w>h', desc = 'Window left' },
        ['<A-Right>'] = { '<C-w>l', desc = 'Window right' },
        ['<A-Down>'] = { '<C-w>j', desc = 'Window down' },
        ['<A-Up>'] = { '<C-w>k', desc = 'Window up' },
    }
}
