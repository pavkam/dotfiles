local utils = require 'user.utils'

vim.api.nvim_create_autocmd("FileType", {
    desc = "Configure the ability to remove items",
    pattern = "qf",
    group = vim.api.nvim_create_augroup('pavkam/qf_delete_items', { clear = true }),
    callback = function(args)
        local maps = {
            n = {
                ['x'] = {
                    function ()
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
                    end,
                    desc = 'Remove item',
                    buffer = args.buf,
                },
            }
        }
        maps.n['<del>'] = maps.n['x']
        maps.n['<bs>'] = maps.n['x']

        utils.map(maps)
    end,
})
