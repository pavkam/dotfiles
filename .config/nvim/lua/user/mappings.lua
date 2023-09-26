local utils = require 'user.utils'

require 'user.commands'
require 'user.auto-commands'

return function(mappings)
    local n = mappings.n
    local v = mappings.v
    local t = mappings.t

    -- clear mappings I do not care about
    utils.unmap(n, {
        '<leader>n',
        '<leader>c',
        '<leader>C',
        '<leader>o',
        '<leader>q',
        '<leader>gh',
        '<leader>gg',
        '<leader>p',
        '<leader>pi',
        '<leader>ps',
        '<leader>pS',
        '<leader>pu',
        '<leader>pU',
        '<leader>pa',
        '<leader>pA',
        '<leader>pv',
        '<leader>pl',
        '<leader>pm',
        '<leader>pM',
        '<leader>t',
        '<leader>tl',
        '<leader>tn',
        '<leader>tu',
        '<leader>tt',
        '<leader>tp',
        '<leader>tf',
        '<leader>th',
        '<leader>tv',
        '<leader>/',
        '<leader>l',

        '<leader>b\\',
        '<leader>b|',
        '<leader>bb',
        '<leader>bd',
        '<leader>bp',
        '<leader>bse',
        '<leader>bsi',
        '<leader>bsm',
        '<leader>bsp',
        '<leader>bsr',
        '<leader>bs',
        '<leader>ls',

        '<C-h>',
        '<C-j>',
        '<C-k>',
        '<C-l>',
        '<C-Up>',
        '<C-Down>',
        '<C-Left>',
        '<C-Right>',

        '<C-s>',
        '<C-q>',
    })

    utils.unmap(v, {
        '<leader>dE',
        '<leader>/',
    })

    -- disable some uneeded keys
    n['<space>'] = { '<Nop>', silent = true }
    v['<space>'] = n['<space>']

    n['s'] = { '<Nop>', silent = true }
    v['s'] = n['s']
    n['='] = { '<Nop>', silent = true }
    v['='] = n['=']
    n['M'] = { '<Nop>', silent = true }

    -- Normal mode
    n['<esc>'] = { '<cmd> noh <cr> <esc>', desc = 'Clear highlight', silent = true }
    n['<leader>u'] = { desc = utils.get_icon('Package', 1, true) .. 'UI/UX' }
    n['n'] = { 'nzzzv', desc='Find previous match' }
    n['N'] = { 'Nzzzv', desc='Fine next match' }
    n['U'] = { '<C-r>', desc='Redo' }

    -- Normal mode: navigation
    n['<A-Tab>'] = { '<C-W>w', desc = 'Switch window' }
    n['<A-Left>'] = { '<C-w>h', desc = 'Window left' }
    n['<A-Right>'] = { '<C-w>l', desc = 'Window right' }
    n['<A-Down>'] = { '<C-w>j', desc = 'Window down' }
    n['<A-Up>'] = { '<C-w>k', desc = 'Window up' }

    n["<leader>bd"] =
        { function() require("astronvim.utils.buffer").close() end, desc = "Close current buffer" }

    -- Normal mode: remaps
    utils.remap(n, '<leader>fb', '<leader>bb', 'Show buffers')
    utils.remap(n, '<leader>w', '<leader>bw', 'Save buffer')
    utils.remap(n, '<leader>lS', '<leader>sz')

    -- Normal mode: plugin-based
    if utils.is_plugin_available 'nvim-dap' then
        local function continue_debug()
            local dap_setup = require 'user.utils.dap'
            dap_setup.continue();
        end

        n['<leader>dj'] = {
            function()
                require('dap').down()
            end,
            desc = 'Down in current stacktrace',
        }

        n['<leader>dk'] = {
            function()
                require('dap').up()
            end,
            desc = 'Up in current stacktrace',
        }

        n['<F5>'] = { continue_debug }
        utils.supmap(n, '<F5>', '<leader>dc', 'Debug: Start/Continue', 'Start/Continue (F5)')
        utils.supmap(n, '<F17>', '<leader>dq', 'Debug: Terminate', 'Terminate Session (Shift-F5)')

        utils.resupmap(n, '<F10>', '<F8>', '<leader>do', 'Debug: Step Over', 'Step Over (F8)')
        utils.resupmap(n, '<F11>', '<F7>', '<leader>di', 'Debug: Step Into', 'Step Into (F7)')
        utils.resupmap(n, '<F23>', '<F20>', '<leader>dO', 'Debug: Step Out', 'Step Out (Shift-F8)')

        utils.remap(n, '<leader>dC', '<leader>dB', 'Conditional Breakpoint')
        utils.remap(n, '<leader>du', '<leader>dU')

        n['<leader>db'].desc = 'Toggle Breakpoint'
        n['<leader>dp'].desc = 'Pause'
        n['<leader>dr'].desc = 'Restart'

        utils.unmap(n, {
            '<F29>',
            '<F21>',
            '<F6>',
            '<F9>',
            '<leader>dQ'
        })

        if utils.is_plugin_available 'nvim-dap-ui' then
            utils.remap(n, '<leader>dh', '<leader>de', 'Inspect Symbol')
        end
    end


    if utils.is_plugin_available 'gitsigns.nvim' then
        n['<leader>gr'] = {
            function() require('gitsigns').reset_hunk() end,
            desc = 'Reset Git hunk'
        }

        n['<leader>gR'] = {
            function() require('gitsigns').reset_buffer() end,
            desc = 'Reset Git buffer'
        }
    end

    if utils.is_plugin_available 'telescope.nvim' then
        n['<C-`>'] = {
            function() require('telescope.builtin').keymaps() end,
            desc = 'Keymaps',
        }
    end

    if utils.is_plugin_available 'neogit' then
        n['<leader>gg'] = {
            function ()
                if vim.bo.filetype == 'NeogitStatus' then
                    require('neogit').close()
                else
                    require('neogit').open()
                end
            end,
            desc = 'Neogit'
        }
    elseif vim.fn.exists(':Lazygit') > 0 then
        n['<leader>gg'] = {
            function ()
                vim.cmd('Lazygit')
            end,
            desc = 'Lazygit'
        }
    end

    if utils.is_plugin_available 'neotest' then
        n['<leader>t'] = { desc = utils.get_icon('DiagnosticWarn', 1, true) .. 'Testing' }
        n['<leader>tU'] = {
            function ()
                require('neotest').summary.toggle()
            end,
            desc = 'Toggle summary view',
        }
        n['<leader>to'] = {
            function ()
                require('neotest').output.open()
            end,
            desc = 'Show test output',
        }
        n['<leader>tw'] = {
            function ()
                require('neotest').watch.toggle()
            end,
            desc = 'Toggle test watching',
        }
        n['<leader>tf'] = {
            function ()
                require('neotest').run.run(vim.fn.expand('%'))
            end,
            desc = 'Run all tests in buffer',
        }
        n['<leader>tr'] = {
            function ()
                require('neotest').run.run()
            end,
            desc = 'Run nearest test in buffer',
        }
        n['<leader>td'] = {
            function ()
                if vim.bo.filetype == 'go' and utils.is_plugin_available 'nvim-dap-go' then
                    require('dap-go').debug_test()
                else
                    require('neotest').run.run({strategy = 'dap'})
                end
            end,
            desc = 'Debug nearest test in buffer',
        }
    end

    if utils.is_plugin_available 'toggleterm.nvim' then
        n['<leader>z'] = { desc = utils.get_icon('Terminal', 1, true) .. 'Terminal' }
        n['<leader>zf'] = {
            '<cmd>ToggleTerm direction=float cmd="git bs"<cr>',
            desc = 'Floating terminal'
        }
        n['<leader>zh'] = {
            '<cmd>ToggleTerm size=10 direction=horizontal<cr>',
            desc = 'Horizontal terminal'
        }
        n['<leader>zv'] = {
            '<cmd>ToggleTerm size=80 direction=vertical<cr>',
            desc = 'Vertical terminal'
        }
    end

    if utils.is_plugin_available 'nvim-tmux-navigation' then
        local nvim_tmux_nav = require('nvim-tmux-navigation')

        n['<A-Tab>'][1] = nvim_tmux_nav.NvimTmuxNavigateLastActive
        n['<A-Left>'][1] = nvim_tmux_nav.NvimTmuxNavigateLeft
        n['<A-Right>'][1] = nvim_tmux_nav.NvimTmuxNavigateRight
        n['<A-Down>'][1] = nvim_tmux_nav.NvimTmuxNavigateDown
        n['<A-Up>'][1] = nvim_tmux_nav.NvimTmuxNavigateUp
    end

    -- quick fix and location lists
    n['<leader>q'] = { desc = utils.get_icon('Bookmarks', 1, true) .. 'Lists' }
    n['<leader>qa'] = {
        function ()
            local r, c = unpack(vim.api.nvim_win_get_cursor(0))
            local line = vim.api.nvim_get_current_line()
            if not line or line == '' then
                line = '<empty>'
            end

            vim.fn.setqflist({
                {
                    bufnr = vim.api.nvim_get_current_buf(),
                    lnum = r,
                    col = c,
                    text = line
                },
            }, "a")
        end,
        desc = 'Add quick-fix item'
    }

    n['<leader>qc'] = {
        function ()
            vim.fn.setqflist({}, "r")
        end,
        desc = 'Clear quick-fix list'
    }

    n['<leader>qA'] = {
        function ()
            local r, c = unpack(vim.api.nvim_win_get_cursor(0))
            local line = vim.api.nvim_get_current_line()
            if not line or line == '' then
                line = '<empty>'
            end

            vim.fn.setloclist(0, {
                {
                    bufnr = vim.api.nvim_get_current_buf(),
                    lnum = r,
                    col = c,
                    text = line
                },
            }, "a")
        end,
        desc = 'Add location item'
    }

    n['<leader>qC'] = {
        function ()
            vim.fn.setloclist(0, {})
        end,
        desc = 'Clear locations list'
    }

    n['<leader>qQ'] = {
        "<cmd> copen <cr>",
        desc = 'Show quick-fix list'
    }

    n['<leader>qL'] = {
        "<cmd> lopen <cr>",
        desc = 'Show locations list'
    }

    n[']q'] = {
        "<cmd> cnext <cr>",
        desc = 'Next quick-fix item'
    }
    n['[q'] = {
        "<cmd> cprev <cr>",
        desc = 'Prev quick-fix item'
    }
    n[']l'] = {
        "<cmd> lNext <cr>",
        desc = 'Next location item'
    }
    n['[l'] = {
        "<cmd> lprev <cr>",
        desc = 'Prev location item'
    }

    -- Visual mode
    v['J'] = { ":m '>+1<CR>gv=gv", desc='Move selection downward' }
    v['K'] = { ":m '<-2<CR>gv=gv", desc='Move selection upward' }

    -- Terminal mode
    t['<esc><esc>'] = { '<C-\\><C-n>', desc = 'Exit terminal mode' }

    return mappings
end
