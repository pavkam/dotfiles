local utils = require 'user.utils'

require 'user.commands'
require 'user.auto-commands'

return function(mappings)
    local n = mappings.n
    local v = mappings.v
    local t = mappings.t


    -- disable some uneeded keys

    n['s'] = { '<Nop>', silent = true }
    v['s'] = n['s']
    n['='] = { '<Nop>', silent = true }
    v['='] = n['=']
    n['M'] = { '<Nop>', silent = true }





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

    return mappings
end
