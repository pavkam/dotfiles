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
            utils.set_mappings({
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
