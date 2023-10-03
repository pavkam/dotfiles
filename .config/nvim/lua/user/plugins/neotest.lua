local astro_utils = require 'astronvim.utils'

return {
    'nvim-neotest/neotest',
    ft = { 'go', 'javascript', 'typescript', 'javascriptreact', 'typescriptreact', 'python' },
    dependencies = {
        'nvim-neotest/neotest-go',
        'nvim-neotest/neotest-jest',
        'marilari88/neotest-vitest',
        'nvim-neotest/neotest-python',
    },
    opts = function(_, opts)
        -- configure jest
        local jest = require('neotest-jest')
        jest = jest({
            jestCommand = 'yarn test --',
            env = {
                CI = true
            },
            cwd = function(path)
                return require('neotest-jest.util').find_package_json_ancestor(path)
            end
        })

        opts.adapters = astro_utils.list_insert_unique(opts.adapters, {
            require 'neotest-go',
            require 'neotest-python',
            require 'neotest-vitest',
            jest,
        })

        return opts
    end,
    init = function()
        local group = vim.api.nvim_create_augroup("pavkam/neotest_buffer_management", { clear = true })
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
}
