local icons = require 'ui.icons'

return {
    'lewis6991/gitsigns.nvim',
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
            local gsa = require 'gitsigns.actions'

            local names = {
                reset_hunk = 'Reset hunk',
                preview_hunk = 'Preview hunk',
                stage_hunk = 'Stage hunk',
                undo_stage_hunk = 'Unstage hunk',
                blame_line = 'Blame line',
                select_hunk = 'Select hunk',
            }

            vim.keymap.set('n', 'gh', function()
                local actions = gsa.get_actions()

                if actions == nil or not next(actions) then
                    return
                end

                -- TODO: not working for preview (the popup gets closed)
                local items = {}
                for name, action in pairs(actions) do
                    table.insert(items, {
                        name = names[name] or name,
                        desc = 'Gitsigns ' .. name,
                        command = action,
                    })
                end

                table.insert(items, {
                    name = 'Stage buffer',
                    command = 'Gitsigns stage_buffer',
                    hl = 'SpecialMenuItem',
                })
                table.insert(items, {
                    name = 'Reset buffer',
                    command = 'Gitsigns reset_buffer',
                    hl = 'SpecialMenuItem',
                })

                require('ui.select').command(items, { at_cursor = true })
            end, { buffer = buffer, desc = 'Inspect change' })

            vim.keymap.set('n', ']h', gs.next_hunk, { buffer = buffer, desc = 'Next hunk' })
            vim.keymap.set('n', '[h', gs.prev_hunk, { buffer = buffer, desc = 'Prev hunk' })
        end,
    },
}
