local utils = require 'user.utils'

if utils.is_plugin_available 'neotest' then
    local group = vim.api.nvim_create_augroup("neotest_buffer_management", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        desc = "Manage neotest buffer lifetime",
        group = group,
        callback = function(args)
            local new_file_name = vim.fn.resolve(vim.fn.expand "%")
            local current_file_name = vim.fn.resolve(vim.fn.expand "#")
            local current_file_type = vim.api.nvim_get_option_value("filetype", { buf = args.buf })

             if (current_file_type == 'neotest-output' or current_file_name == 'Neotest Summary') and vim.fn.maparg("q", "n") == "" then
                vim.keymap.set("n", "q", "<cmd>close<cr>", {
                    desc = "Close window",
                    buffer = args.buf,
                    silent = true,
                    nowait = true,
                })
            end

            if current_file_name == "Neotest Summary" and new_file_name ~= "" and new_file_name ~= current_file_name then
                vim.cmd('b#')
            end
        end,
    })
end
