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

if is_available 'package-info.nvim' then
    vim.api.nvim_create_autocmd('BufRead package.json', {
        desc = 'Configure package.json key mappings',
        group = vim.api.nvim_create_augroup('project_json', { clear = true }),
        callback = function(args)
            local pi = require('package-info')
            utils.set_mappings({
                n = {
                    ['<leader>P'] = {
                        buffer = args.buf,
                        desc = get_icon('GitChange', 1, true) .. 'Package.json',
                    },
                    ['<leader>Pu'] = {
                        pi.update,
                        buffer = args.buf,
                        silent = true,
                        noremap = true,
                        desc = 'Update package version',
                    },
                    ['<leader>Pr'] = {
                        pi.delete,
                        buffer = args.buf,
                        silent = true,
                        noremap = true,
                        desc = 'Remove package',
                    },
                    ['<leader>Pa'] = {
                        pi.install,
                        buffer = args.buf,
                        silent = true,
                        noremap = true,
                        desc = 'Add package',
                    },
                    ['<leader>Pv'] = {
                        pi.change_version,
                        buffer = args.buf,
                        silent = true,
                        noremap = true,
                        desc = 'Change package version',
                    }
                }
            })
        end,
    })
end
