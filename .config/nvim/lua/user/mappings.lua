local utils = require 'astronvim.utils'
local get_icon = utils.get_icon
local is_available = utils.is_available

require 'user.commands'

return function(mappings)
    local n = mappings.n
    local v = mappings.v
    local t = mappings.t

    local remap = function(t, from, to, desc)
        t[to] = t[from]
        t[from] = nil

        if desc ~= nil and t[to] ~= nil then
            t[to].desc = desc
        end
    end

    local unmap = function(t, what)
        for _, k in ipairs(what) do
            t[k] = nil
        end
    end

    -- clear mappings I do not care about
    unmap(n, {
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

    unmap(v, {
        '<leader>dE',
        '<leader>/',
    })

    -- Normal mode
    n['<esc>'] = { '<cmd> noh <cr>', desc = 'Clear highlight', silent = true }
    n['<leader>u'] = { desc = get_icon('Package', 1, true) .. 'UI/UX' }
    n['n'] = {'nzzzv', desc='Find previous match' }
    n['N'] = {'Nzzzv', desc='Fine next match' }

    -- Normal mode: navigation
    n['<A-Tab>'] = { '<C-W>w', desc = 'Switch window' }
    n['<A-Left>'] = { '<C-w>h', desc = 'Window left' }
    n['<A-Right>'] = { '<C-w>l', desc = 'Window right' }
    n['<A-Down>'] = { '<C-w>j', desc = 'Window down' }
    n['<A-Up>'] = { '<C-w>k', desc = 'Window up' }

    n['<leader>bd'] = { '<cmd> bd <cr>', desc = 'Close current buffer' }

    -- Normal mode: remaps
    remap(n, '<leader>fb', '<leader>bb', 'Show buffers')
    remap(n, '<leader>w', '<leader>bw', 'Save buffer')
    remap(n, '<leader>lS', '<leader>sz')
    remap(n, '<leader>ls', '<leader>fs', 'Find symbols')

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

        n['<F5>'] = { continue_debug, desc = 'Debugger: Start' }
        n['<leader>dc'] = { continue_debug, desc = 'Start/Continue (F5)'}
    end

    if is_available 'gitsigns.nvim' then
        n['<leader>gr'] = {
            function() require('gitsigns').reset_hunk() end,
            desc = 'Reset Git hunk'
        }

        n['<leader>gR'] = {
            function() require('gitsigns').reset_buffer() end,
            desc = 'Reset Git buffer'
        }
    end

    if is_available 'telescope.nvim' then
        n['<C-`>'] = {
            function() require('telescope.builtin').keymaps() end,
            desc = 'Keymaps',
        }
    end

    if is_available 'neogit' then
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
    end

    if is_available 'neotest' then
        n['<leader>t'] = { desc = utils.get_icon('DiagnosticWarn', 1, true) .. 'Testing' }
        n['<leader>t|'] = {
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
        n['<leader>z'] = { desc = get_icon('Terminal', 1, true) .. 'Terminal' }
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

    if is_available 'nvim-tmux-navigation' then
        local nvim_tmux_nav = require('nvim-tmux-navigation')

        n['<A-Tab>'][1] = nvim_tmux_nav.NvimTmuxNavigateLastActive
        n['<A-Left>'][1] = nvim_tmux_nav.NvimTmuxNavigateLeft
        n['<A-Right>'][1] = nvim_tmux_nav.NvimTmuxNavigateRight
        n['<A-Down>'][1] = nvim_tmux_nav.NvimTmuxNavigateDown
        n['<A-Up>'][1] = nvim_tmux_nav.NvimTmuxNavigateUp
    end

    -- Visual mode
    v['J'] = { ":m '>+1<CR>gv=gv", desc='Move selection downward' }
    v['K'] = { ":m '<-2<CR>gv=gv", desc='Move selection upward' }

    -- Terminal mode
    t['<esc><esc>'] = { '<C-\\><C-n>', desc = 'Exit terminal mode' }

    return mappings
end

















