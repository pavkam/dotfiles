local icons = require 'ui.icons'
local shell = require 'core.shell'

return {
    'lewis6991/gitsigns.nvim',
    cond = feature_level(2),
    event = 'User GitFile',
    opts = {
        signs = {
            add = { text = icons.Git.Signs.Add },
            change = { text = icons.Git.Signs.Change },
            delete = { text = icons.Git.Signs.Delete },
            topdelete = { text = icons.Git.Signs.TopDelete },
            changedelete = { text = icons.Git.Signs.ChangeDelete },
            untracked = { text = icons.Git.Signs.Untracked },
        },
        on_attach = function(buffer)
            local gs = require 'gitsigns'

            vim.keymap.set('n', ']h', gs.next_hunk, { buffer = buffer, desc = 'Next hunk' })
            vim.keymap.set('n', '[h', gs.prev_hunk, { buffer = buffer, desc = 'Prev hunk' })
            vim.keymap.set({ 'n', 'v' }, '<leader>gs', ':Gitsigns stage_hunk<CR>', { buffer = buffer, desc = 'Stage hunk' })
            vim.keymap.set({ 'n', 'v' }, '<leader>gr', ':Gitsigns reset_hunk<CR>', { buffer = buffer, desc = 'Reset hunk' })
            vim.keymap.set('n', '<leader>gS', gs.stage_buffer, { buffer = buffer, desc = 'Stage buffer' })
            vim.keymap.set('n', '<leader>gu', gs.undo_stage_hunk, { buffer = buffer, desc = 'Undo stage hunk' })
            vim.keymap.set('n', '<leader>gR', gs.reset_buffer, { buffer = buffer, desc = 'Reset buffer' })
            vim.keymap.set('n', '<leader>gp', gs.preview_hunk, { buffer = buffer, desc = 'Preview hunk' })
            vim.keymap.set('n', '<leader>gB', function()
                gs.blame_line { full = true }
            end, { buffer = buffer, desc = 'Blame line' })
            vim.keymap.set('n', '<leader>gd', gs.diffthis, { buffer = buffer, desc = 'Diff this' })
            vim.keymap.set('n', '<leader>gD', function()
                gs.diffthis '~'
            end, { buffer = buffer, desc = 'Diff This ~' })
            vim.keymap.set({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { buffer = buffer, desc = 'Select hunk' })
        end,
    },
}
