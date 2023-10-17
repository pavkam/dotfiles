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
    keys = {
            {
            "<leader>qa",
            function ()
                local r, c = unpack(vim.api.nvim_win_get_cursor(0))
                local line = vim.api.nvim_get_current_line()
                if not line or line == '' then
                    line = '<empty>'
                end

                vim.fn.setqflist({
                    {
                        bufnr = vim.api.nvim_get_current_buf(),
                        lnum = r,
                        col = c,
                        text = line
                    },
                }, "a")
            end,
            mode = { "n" },
            desc = "Add quick-fix item"
        },
        {
            "<leader>qc",
            function ()
                vim.fn.setqflist({}, "r")
            end,
            mode = { "n" },
            desc = 'Clear quick-fix list'
        },
        {
            "<leader>qA",
            function ()
                local r, c = unpack(vim.api.nvim_win_get_cursor(0))
                local line = vim.api.nvim_get_current_line()
                if not line or line == '' then
                    line = '<empty>'
                end

                vim.fn.setloclist(0, {
                    {
                        bufnr = vim.api.nvim_get_current_buf(),
                        lnum = r,
                        col = c,
                        text = line
                    },
                }, "a")
            end,
            mode = { "n" },
            desc = 'Add location item'
        },
        {
            "<leader>qC",
            function ()
                vim.fn.setloclist(0, {})
            end,
            mode = { "n" },
            desc = 'Clear locations list'
        },
        {
            "<leader>qQ",
            "<cmd> copen <cr>",
            mode = { "n" },
            desc = 'Show quick-fix list'
        },
        {
            "<leader>qL",
            "<cmd> lopen <cr>",
            mode = { "n" },
            desc = 'Show locations list'
        },
        {
            "]q",
            "<cmd> cnext <cr>",
            mode = { "n" },
            desc = 'Next quick-fix item'
        },
        {
            "[q",
            "<cmd> cprev <cr>",
            mode = { "n" },
            desc = 'Prev quick-fix item'
        },
        {
            "]l",
            "<cmd> lnext <cr>",
            mode = { "n" },
            desc = 'Next location item'
        },
        {
            "[l",
            "<cmd> lprev <cr>",
            mode = { "n" },
            desc = 'Prev location item'
        },
    },
    config = function()
        local utils = require "utils"

        utils.auto_command("FileType", function(args)
            vim.keymap.set('n', 'q', '<cmd>close<cr>', { remap = true, desc = 'Close Window', buffer = args.buf })
            vim.keymap.set('n', 'x', function ()
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
            end, { expr = true, silent = true, desc = 'Remove Item', buffer = args.buf })

            vim.keymap.set('n', '<del>', 'x', { remap = true, desc = 'Remove Item', buffer = args.buf })
            vim.keymap.set('n', '<bs>', 'x', { remap = true, desc = 'Remove Item', buffer = args.buf })
        end, "qf")
    end
}
