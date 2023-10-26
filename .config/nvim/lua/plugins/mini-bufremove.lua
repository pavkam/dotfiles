return {
    "echasnovski/mini.bufremove",
    keys = {
        {
            "<leader>bd",
             function()
                local ui = require "utils.ui"
                local bufremove = require "mini.bufremove"

                local buffer = vim.api.nvim_get_current_buf()
                if vim.bo.modified then
                    local choice = vim.fn.confirm(("Save changes to %q?"):format(vim.fn.bufname(buffer)), "&Yes\n&No\n&Cancel")
                    if choice == 1 then -- Yes
                        vim.api.nvim_buf_call(buffer, vim.cmd.write)
                        bufremove.delete(buffer)
                    elseif choice == 2 then -- No
                        bufremove.delete(buffer, true)
                    end
                else
                    bufremove.delete(buffer)
                end
            end,
            desc = "Delete buffer"
        },
        { "<leader>bD", function() require("mini.bufremove").delete(0, true) end, desc = "Delete buffer (force)" },
    },
}
