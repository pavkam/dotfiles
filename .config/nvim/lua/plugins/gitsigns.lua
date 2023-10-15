local icons = require "utils.icons"
local utils = require "utils"

return {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        signs = {
            add = { text = icons.git.Signs.Add },
            change = { text = icons.git.Signs.Change },
            delete = { text = icons.git.Signs.Delete },
            topdelete = { text = icons.git.Signs.TopDelete },
            changedelete = { text = icons.git.Signs.ChangeDelete },
            untracked = { text = icons.git.Signs.Untracked },
        },
        on_attach = function(buffer)
            local gs = require 'gitsigns'

            local function map(mode, l, r, desc)
                vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
            end

            vim.keymap.set("n", "]h", gs.next_hunk, { buffer = buffer, desc = "Next Hunk"})
            vim.keymap.set("n", "[h", gs.prev_hunk, { buffer = buffer, desc = "Prev Hunk"})
            vim.keymap.set({ "n", "v" }, "<leader>gs", ":Gitsigns stage_hunk<CR>", { buffer = buffer, desc = "Stage Hunk"})
            vim.keymap.set({ "n", "v" }, "<leader>gr", ":Gitsigns reset_hunk<CR>", { buffer = buffer, desc = "Reset Hunk"})
            vim.keymap.set("n", "<leader>gS", gs.stage_buffer, { buffer = buffer, desc = "Stage Buffer"})
            vim.keymap.set("n", "<leader>gu", gs.undo_stage_hunk, { buffer = buffer, desc = "Undo Stage Hunk"})
            vim.keymap.set("n", "<leader>gR", gs.reset_buffer, { buffer = buffer, desc = "Reset Buffer"})
            vim.keymap.set("n", "<leader>gp", gs.preview_hunk, { buffer = buffer, desc = "Preview Hunk"})
            vim.keymap.set("n", "<leader>gb", function() gs.blame_line({ full = true }) end, { buffer = buffer, desc = "Blame Line"})
            vim.keymap.set("n", "<leader>gd", gs.diffthis, { buffer = buffer, desc = "Diff This"})
            vim.keymap.set("n", "<leader>gD", function() gs.diffthis("~") end, { buffer = buffer, desc = "Diff This ~"})
            vim.keymap.set({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { buffer = buffer, desc = "Select Hunk"})

            if vim.fn.executable 'lazygit' == 1 then
                vim.api.nvim_buf_create_user_command(
                    buffer,
                    'Lazygit',
                    function()
                        utils.float_term('lazygit')
                    end,
                    { desc = 'Run Lazygit', nargs = 0 }
                )

                vim.keymap.set("n", "<leader>gg", function () vim.cmd('Lazygit') end, { desc = "Lazygit"})
            end


        end,
    }
}
