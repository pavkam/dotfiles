local shell = require 'core.shell'

-- Add a command to run lazygit
if vim.fn.executable 'lazygit' == 1 then
    vim.api.nvim_create_user_command('Lazygit', function()
        shell.floating 'lazygit'
    end, { desc = 'Run Lazygit', nargs = 0 })

    vim.keymap.set('n', '<leader>gg', function()
        vim.cmd 'Lazygit'
    end, { desc = 'Lazygit' })
end
