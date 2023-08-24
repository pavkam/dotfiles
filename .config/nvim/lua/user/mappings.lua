local utils = require 'astronvim.utils'
local get_icon = utils.get_icon
local is_available = utils.is_available

local mappings = {
    n = {
        ['<leader>bw'] = { '<cmd>w<cr>', desc = 'Save buffer' },

        ['<leader>w'] = { desc = get_icon('Window', 1, true) .. 'Window' },
        ['<leader>wq'] = { '<cmd>confirm qa<cr>', desc = 'Quit' },
        ['<leader>wc'] = { '<cmd>confirm q<cr>', desc = 'Close' },

        ['<leader>u'] = { desc = get_icon('Package', 1, true) .. 'UI/UX' },


        ['n'] = {'nzzzv', desc='Find previous match' },
        ['N'] = {'Nzzzv', desc='Fine next match' },
    },
    i = {
    },
    v = {
        ['J'] = { ":m '>+1<CR>gv=gv", desc='Move selection downward' },
        ['K'] = { ":m '<-2<CR>gv=gv", desc='Move selection upward' },
    },
    t = {
        ['<esc><esc>'] = { '<C-\\><C-n>', desc = 'Exit terminal mode' },
    }
}

-- clear useless mappings
mappings.n = vim.tbl_extend('force', mappings.n, {
    ['<leader>c'] = false,
    ['<leader>C'] = false,
    ['<leader>e'] = false,
    ['<leader>o'] = false,
    ['<leader>q'] = false,
    ['<leader>gh'] = false,
    ['<leader>gg'] = false,
    ['<leader>p'] = false,
    ['<leader>pi'] = false,
    ['<leader>ps'] = false,
    ['<leader>pS'] = false,
    ['<leader>pu'] = false,
    ['<leader>pU'] = false,
    ['<leader>pa'] = false,
    ['<leader>pA'] = false,
    ['<leader>pv'] = false,
    ['<leader>pl'] = false,
    ['<leader>pm'] = false,
    ['<leader>pM'] = false,
    ['<leader>t'] = false,
    ['<leader>tl'] = false,
    ['<leader>tn'] = false,
    ['<leader>tu'] = false,
    ['<leader>tt'] = false,
    ['<leader>tp'] = false,
    ['<leader>tf'] = false,
    ['<leader>th'] = false,
    ['<leader>tv'] = false,
})

-- add common mappings

local window_nav_mappings = {
    ['<A-Tab>'] = { '<C-W>w', desc = 'Switch window' },
    ['<A-Left>'] = { '<C-w>h', desc = 'Window left' },
    ['<A-Right>'] = { '<C-w>l', desc = 'Window right' },
    ['<A-Down>'] = { '<C-w>j', desc = 'Window down' },
    ['<A-Up>'] = { '<C-w>k', desc = 'Window up' },
}

local buffer_nav_mappings = {
     ['<A-S-Right>'] = { '<cmd> bnext <cr>', desc = 'Buffer next' },
     ['<A-S-Left>'] = { '<cmd> bprev <cr>', desc = 'Buffer previous' },
}

mappings.n = vim.tbl_extend('force', mappings.n, window_nav_mappings, buffer_nav_mappings)
mappings.i = vim.tbl_extend('force', mappings.i, window_nav_mappings, buffer_nav_mappings)
mappings.v = vim.tbl_extend('force', mappings.v, window_nav_mappings, buffer_nav_mappings)
mappings.t = vim.tbl_extend('force', mappings.t, window_nav_mappings)

-- plugin-dependant mappings
if is_available 'nvim-dap' then
    local function continue_debug()
        if vim.fn.filereadable('.vscode/launch.json') then
            local jsl = { 'typescript', 'javascript', 'typescriptreact', 'javascriptreact' }
            require('dap.ext.vscode').load_launchjs(nil, {
                ['pwa-node'] = jsl,
                ['node'] = jsl,
                ['chrome'] = jsl,
                ['pwa-chrome'] = jsl
            })
        end

        require('dap').continue();
    end

    mappings.n = vim.tbl_extend('force', mappings.n, {
        ['<F5>'] = {
            continue_debug,
            desc = 'Debugger: Start',
        },
        ['<leader>dc'] = {
            continue_debug,
            desc = 'Start/Continue (F5)',
        },
    })
end

if is_available 'gitsigns.nvim' then
    mappings.n = vim.tbl_extend('force', mappings.n, {
        ['<leader>gr'] = {
            function() require('gitsigns').reset_hunk() end,
            desc = 'Reset Git hunk'
        },
        ['<leader>gR'] = {
            function() require('gitsigns').reset_buffer() end,
            desc = 'Reset Git buffer'
        },
    })
end

if is_available 'telescope.nvim' then
    mappings.n = vim.tbl_extend('force', mappings.n, {
        ['<C-`>'] = {
            function() require('telescope.builtin').keymaps() end,
            desc = 'Keymaps',
        },
    })
end

if is_available 'neo-tree.nvim' then
    mappings.n = vim.tbl_extend('force', mappings.n, {
         ['<leader>we'] = {
            '<cmd>Neotree toggle<cr>',
            desc = 'File explorer'
        },
    })
end

if is_available 'neogit' then
    mappings.n = vim.tbl_extend('force', mappings.n, {
        ['<leader>gg'] = {
            function ()
                if vim.bo.filetype == 'NeogitStatus' then
                    require('neogit').close()
                else
                    require('neogit').open()
                end
            end,
            desc = 'Neogit'
        },
    })
end

if is_available 'neotest' then
    mappings.n = vim.tbl_extend('force', mappings.n, {
        ['<leader>t'] = { desc = utils.get_icon('DiagnosticWarn', 1, true) .. 'Testing' },
        ['<leader>ts'] = {
            function ()
                require('neotest').summary.toggle()
            end,
            desc = 'Toggle summary view',
        },
        ['<leader>to'] = {
            function ()
                require('neotest').output.open()
            end,
            desc = 'Show test output',
        },
        ['<leader>tw'] = {
            function ()
                require('neotest').watch.toggle()
            end,
            desc = 'Toggle test watching',
        },
        ['<leader>tf'] = {
            function ()
                require('neotest').run.run(vim.fn.expand('%'))
            end,
            desc = 'Run all tests in buffer',
        },
        ['<leader>tr'] = {
            function ()
                require('neotest').run.run()
            end,
            desc = 'Run nearest test in buffer',
        },
        ['<leader>td'] = {
            function ()
                if vim.bo.filetype == 'go' and utils.is_available 'nvim-dap-go' then
                    require('dap-go').debug_test()
                else
                    require('neotest').run.run({strategy = 'dap'})
                end
            end,
            desc = 'Debug nearest test in buffer',
        },
    })
end

if is_available 'toggleterm.nvim' then
    mappings.n = vim.tbl_extend('force', mappings.n, {
        ['<leader>z'] = { desc = get_icon('Terminal', 1, true) .. 'Terminal' },
        ['<leader>zf'] = {
            '<cmd>ToggleTerm direction=float<cr>',
            desc = 'Floating terminal'
        },
        ['<leader>zh'] = {
            '<cmd>ToggleTerm size=10 direction=horizontal<cr>',
            desc = 'Horizontal terminal'
        },
        ['<leader>zv'] = {
            '<cmd>ToggleTerm size=80 direction=vertical<cr>',
            desc = 'Vertical terminal'
        },
    })
end

return mappings
