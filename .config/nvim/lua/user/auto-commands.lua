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

if utils.is_plugin_available 'package-info.nvim' then
    vim.api.nvim_create_autocmd('BufRead', {
        pattern = 'package\\.json',
        desc = 'Configure package.json key mappings',
        group = vim.api.nvim_create_augroup('project_json', { clear = true }),
        callback = function(args)
            local pi = require('package-info')
            utils.map({
                n = {
                    ['<leader>P'] = {
                        buffer = args.buf,
                        desc = utils.get_icon('GitChange', 1, true) .. 'Package.json',
                    },
                    ['<leader>Pu'] = {
                        pi.update,
                        desc = 'Update package version',
                    },
                    ['<leader>Pr'] = {
                        pi.delete,
                        desc = 'Remove package',
                    },
                    ['<leader>Pa'] = {
                        pi.install,
                        desc = 'Add package',
                    },
                    ['<leader>Pv'] = {
                        pi.change_version,
                        desc = 'Change package version',
                    }
                }
            }, {
                buffer = args.buf,
                silent = true,
                noremap = true,
            })
        end,
    })
end

vim.api.nvim_create_autocmd("FileType", {
    desc = "Configure the ability to remove items",
    pattern = "qf",
    group = vim.api.nvim_create_augroup('qf_delete_items', { clear = true }),
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
