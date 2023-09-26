local utils = require 'user.utils'
local astro_utils = require 'astronvim.utils'

if utils.is_plugin_available 'toggleterm.nvim' then
    if vim.fn.executable 'lazygit' == 1 then
        vim.api.nvim_create_user_command(
            'Lazygit',
            function()
                local worktree = require('astronvim.utils.git').file_worktree()
                local flags = worktree and (' --work-tree=%s --git-dir=%s'):format(worktree.toplevel, worktree.gitdir) or ''
                astro_utils.toggle_term_cmd('lazygit ' .. flags)
            end,
            { desc = 'Open Lazygit in Terminal', nargs = 0 }
        )
    end
end
