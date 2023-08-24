local utils = require 'astronvim.utils'

return {
    {
        'nvim-neotest/neotest',
        ft = { 'go', 'javascript', 'typescript', 'javascriptreact', 'typescriptreact', 'python' },
        dependencies = {
            'nvim-lua/plenary.nvim',
            'nvim-neotest/neotest-go',
            'nvim-neotest/neotest-jest',
            'marilari88/neotest-vitest',
            'nvim-neotest/neotest-python',
            {
                'folke/neodev.nvim',
                opts = function(_, opts)
                    opts.library = opts.library or {}
                    if opts.library.plugins ~= true then
                        opts.library.plugins = require('astronvim.utils').list_insert_unique(opts.library.plugins, 'neotest')
                    end
                    opts.library.types = true
                end,
            },
        },
        opts = function()
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

            return {
                adapters = {
                    require 'neotest-go',
                    require 'neotest-python',
                    require 'neotest-vitest',
                    jest,
                },
            }
        end,
    },
    {
        'catppuccin/nvim',
        optional = true,
        opts = { integrations = { neotest = true } },
    },
}
