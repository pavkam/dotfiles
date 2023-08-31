local utils = require 'astronvim.utils'
local get_icon = utils.get_icon
local is_available = utils.is_available

require 'user.commands'

return function(mappings)
    -- clear mappings I do not care about
    mappings.n['<leader>c'] = nil
    mappings.n['<leader>C'] = nil
    mappings.n['<leader>e'] = nil
    mappings.n['<leader>o'] = nil
    mappings.n['<leader>q'] = nil
    mappings.n['<leader>gh'] = nil
    mappings.n['<leader>gg'] = nil
    mappings.n['<leader>p'] = nil
    mappings.n['<leader>pi'] = nil
    mappings.n['<leader>ps'] = nil
    mappings.n['<leader>pS'] = nil
    mappings.n['<leader>pu'] = nil
    mappings.n['<leader>pU'] = nil
    mappings.n['<leader>pa'] = nil
    mappings.n['<leader>pA'] = nil
    mappings.n['<leader>pv'] = nil
    mappings.n['<leader>pl'] = nil
    mappings.n['<leader>pm'] = nil
    mappings.n['<leader>pM'] = nil
    mappings.n['<leader>t'] = nil
    mappings.n['<leader>tl'] = nil
    mappings.n['<leader>tn'] = nil
    mappings.n['<leader>tu'] = nil
    mappings.n['<leader>tt'] = nil
    mappings.n['<leader>tp'] = nil
    mappings.n['<leader>tf'] = nil
    mappings.n['<leader>th'] = nil
    mappings.n['<leader>tv'] = nil
    mappings.n['<leader>/'] = nil

    -- Normal mode
    mappings.n['<leader>bw'] = { '<cmd>w<cr>', desc = 'Save buffer' }
    mappings.n['<leader>w'] = { desc = get_icon('Window', 1, true) .. 'Window' }
    mappings.n['<leader>wq'] = { '<cmd>confirm qa<cr>', desc = 'Quit' }
    mappings.n['<leader>wc'] = { '<cmd>confirm q<cr>', desc = 'Close' }
    mappings.n['<leader>u'] = { desc = get_icon('Package', 1, true) .. 'UI/UX' }
    mappings.n['n'] = {'nzzzv', desc='Find previous match' }
    mappings.n['N'] = {'Nzzzv', desc='Fine next match' }

    -- Normal mode: navigation
    mappings.n['<A-Tab>'] = { '<C-W>w', desc = 'Switch window' }
    mappings.n['<A-Left>'] = { '<C-w>h', desc = 'Window left' }
    mappings.n['<A-Right>'] = { '<C-w>l', desc = 'Window right' }
    mappings.n['<A-Down>'] = { '<C-w>j', desc = 'Window down' }
    mappings.n['<A-Up>'] = { '<C-w>k', desc = 'Window up' }
    mappings.n['<S-Tab>'] = { '<cmd> tabnext <cr>', desc = 'Tab next' }
    mappings.n['<C-Right>'] = { '<cmd> bnext <cr>', desc = 'Buffer next' }
    mappings.n['<C-l>'] = { '<cmd> bnext <cr>', desc = 'Buffer next' }
    mappings.n['<C-Left>'] = { '<cmd> bprev <cr>', desc = 'Buffer previous' }
    mappings.n['<C-h>'] = { '<cmd> bprev <cr>', desc = 'Buffer previous' }

    -- Normal mode: remaps
    mappings.n["<leader>s|"] = mappings.n["<leader>lS"]
    mappings.n["<leader>lS"] = nil
    mappings.n["<leader>ss"] = mappings.n["<leader>ls"]
    mappings.n["<leader>ls"] = nil
    mappings.n['<leader>s'] = { desc = get_icon('ActiveLSP', 1, true) .. 'Source/Symbol' }
    mappings.n['<leader>l'] = nil

    -- Normal mode: plugin-based
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

        mappings.n['<F5>'] = { continue_debug, desc = 'Debugger: Start' }
        mappings.n['<leader>dc'] = { continue_debug, desc = 'Start/Continue (F5)'}
    end

    if is_available 'gitsigns.nvim' then
        mappings.n['<leader>gr'] = {
            function() require('gitsigns').reset_hunk() end,
            desc = 'Reset Git hunk'
        }

        mappings.n['<leader>gR'] = {
            function() require('gitsigns').reset_buffer() end,
            desc = 'Reset Git buffer'
        }
    end

    if is_available 'telescope.nvim' then
        mappings.n['<C-`>'] = {
            function() require('telescope.builtin').keymaps() end,
            desc = 'Keymaps',
        }
    end

    if is_available 'neo-tree.nvim' then
        mappings.n['<leader>we'] = {
            '<cmd>Neotree toggle<cr>',
            desc = 'File explorer'
        }
    end

    if is_available 'neogit' then
        mappings.n['<leader>gg'] = {
            function ()
                if vim.bo.filetype == 'NeogitStatus' then
                    require('neogit').close()
                else
                    require('neogit').open()
                end
            end,
            desc = 'Neogit'
        }
    end

    if is_available 'neotest' then
        mappings.n['<leader>t'] = { desc = utils.get_icon('DiagnosticWarn', 1, true) .. 'Testing' }
        mappings.n['<leader>t|'] = {
            function ()
                require('neotest').summary.toggle()
            end,
            desc = 'Toggle summary view',
        }
        mappings.n['<leader>to'] = {
            function ()
                require('neotest').output.open()
            end,
            desc = 'Show test output',
        }
        mappings.n['<leader>tw'] = {
            function ()
                require('neotest').watch.toggle()
            end,
            desc = 'Toggle test watching',
        }
        mappings.n['<leader>tf'] = {
            function ()
                require('neotest').run.run(vim.fn.expand('%'))
            end,
            desc = 'Run all tests in buffer',
        }
        mappings.n['<leader>tr'] = {
            function ()
                require('neotest').run.run()
            end,
            desc = 'Run nearest test in buffer',
        }
        mappings.n['<leader>td'] = {
            function ()
                if vim.bo.filetype == 'go' and utils.is_available 'nvim-dap-go' then
                    require('dap-go').debug_test()
                else
                    require('neotest').run.run({strategy = 'dap'})
                end
            end,
            desc = 'Debug nearest test in buffer',
        }
    end

    if is_available 'toggleterm.nvim' then
        mappings.n['<leader>z'] = { desc = get_icon('Terminal', 1, true) .. 'Terminal' }
        mappings.n['<leader>zf'] = {
            '<cmd>ToggleTerm direction=float<cr>',
            desc = 'Floating terminal'
        }
        mappings.n['<leader>zh'] = {
            '<cmd>ToggleTerm size=10 direction=horizontal<cr>',
            desc = 'Horizontal terminal'
        }
        mappings.n['<leader>zv'] = {
            '<cmd>ToggleTerm size=80 direction=vertical<cr>',
            desc = 'Vertical terminal'
        }
    end

    -- Visual mode
    mappings.v['J'] = { ":m '>+1<CR>gv=gv", desc='Move selection downward' }
    mappings.v['K'] = { ":m '<-2<CR>gv=gv", desc='Move selection upward' }

    -- Terminal mode
    mappings.t['<esc><esc>'] = { '<C-\\><C-n>', desc = 'Exit terminal mode' }

    return mappings
end

















