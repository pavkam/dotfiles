return {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    opts = {
        func_map = {
            split = '\\',
            vsplit = '|',
            tab = '',
            tabb = '',
            tabc = '',
            lastleave = '',
            fzffilter = '',
            filterr = '',
            filter = '',
            ptoggleauto = '',
            ptoggleitem = '',
            ptogglemode = '',
            pscrollorig = '',
        }
    },
    config = function()
        local utils = require "utils"

        utils.on_event("FileType", function(args)
            vim.keymap.set('n', 'q', '<cmd>close<cr>', { remap = true, desc = 'Close Window', buffer = args.buf })
            vim.keymap.set('n', 'x', function ()
                require('bqf').hidePreviewWindow()

                local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
                local qftype
                if info.quickfix == 0 then
                    qftype = nil
                elseif info.loclist == 0 then
                    qftype = "c"
                else
                    qftype = "l"
                end

                local list = qftype == "l" and vim.fn.getloclist(0) or vim.fn.getqflist()
                local r, c = unpack(vim.api.nvim_win_get_cursor(0))

                table.remove(list, r)

                if qftype == "l" then
                    vim.fn.setloclist(0, list)
                else
                    vim.fn.setqflist(list)
                end

                r = math.min(r, #list)
                if (r > 0) then
                    vim.api.nvim_win_set_cursor(0, { r, c })
                end
            end, { desc = 'Remove item', buffer = args.buf })

            vim.keymap.set('n', '<del>', 'x', { remap = true, desc = 'Remove Item', buffer = args.buf })
            vim.keymap.set('n', '<bs>', 'x', { remap = true, desc = 'Remove Item', buffer = args.buf })
        end, "qf")
    end
}
