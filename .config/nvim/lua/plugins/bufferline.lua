local icons = require "utils.icons"

return {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    event = "BufEnter",
    keys = {
        { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
        { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Un-pinned buffers" },
        { "[b", "<Cmd>BufferLineCyclePrev<CR>", desc = "Previous Buffer" },
        { "]b", "<Cmd>BufferLineCycleNext<CR>", desc = "Previous Buffer" },
    },
    opts = {
        options = {
            close_command = function(n) require("mini.bufremove").delete(n, false) end,
            right_mouse_command = function(n) require("mini.bufremove").delete(n, false) end,

            diagnostics = "nvim_lsp",
            always_show_bufferline = false,

            diagnostics_indicator = function(_, _, diag)
                local ret = (diag.error and icons.Diagnostics.LSP.Error .. " " .. diag.error or "")
                    .. (diag.warning and icons.Diagnostics.LSP.Warn .. " " .. diag.warning or "")
                return vim.trim(ret)
            end,
            offsets = {
                {
                    filetype = "neo-tree",
                    text = "Neo-tree",
                    highlight = "Directory",
                    text_align = "left",
                },
            },
        },
    },
     config = function(_, opts)
        local utils = require "utils"
        local buffer_line = require "bufferline"
        buffer_line.setup(opts)

        -- Fix bufferline when restoring a session
        utils.auto_command(
            "BufAdd",
            function()
                vim.schedule(function() pcall(nvim_bufferline) end)
            end
        )
    end,
}
