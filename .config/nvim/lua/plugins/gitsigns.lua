local icons = require 'icons'

return {
    'lewis6991/gitsigns.nvim',
    cond = not vim.headless,
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
            local keys = require 'keys'
            local gs = require 'gitsigns'

            local actions = {
                reset_hunk = { 'Reset hunk', 'r' },
                preview_hunk_inline = { 'Preview hunk', 'h' },
                stage_hunk = { 'Stage hunk', 's' },
                undo_stage_hunk = { 'Unstage hunk', 'u' },
                blame_line = { 'Blame line', 'b' },
                select_hunk = { 'Select hunk', 'x' },
                stage_buffer = { 'Stage buffer', 'S' },
                reset_buffer = { 'Reset buffer', 'R' },
            }

            for name, details in pairs(actions) do
                keys.map(
                    'n',
                    'gh' .. details[2],
                    '<cmd>Gitsigns ' .. name .. '<CR>',
                    { buffer = buffer, desc = details[1] }
                )
            end

            vim.keymap.set('n', ']h', gs.next_hunk, { buffer = buffer, desc = 'Next hunk' })
            vim.keymap.set('n', '[h', gs.prev_hunk, { buffer = buffer, desc = 'Prev hunk' })
        end,
    },
}
