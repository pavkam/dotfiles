local utils = require 'astronvim.utils'
local is_available = utils.is_available
local get_icon = utils.get_icon

if is_available 'toggleterm.nvim' then
    if vim.fn.executable 'lazygit' == 1 then
        vim.api.nvim_create_user_command(
            'Lazygit',
            function()
                local worktree = require('astronvim.utils.git').file_worktree()
                local flags = worktree and (' --work-tree=%s --git-dir=%s'):format(worktree.toplevel, worktree.gitdir) or ''
                utils.toggle_term_cmd('lazygit ' .. flags)
            end,
            { desc = 'Open Lazygit in Terminal', nargs = 0 }
        )
    end
end
