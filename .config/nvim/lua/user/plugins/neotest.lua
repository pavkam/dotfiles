return {
    {
        'nvim-neotest/neotest',
        ft = { 'go', 'javascript', 'typescript', 'javascriptreact', 'typescriptreact', 'python' },
        dependencies = {
            'nvim-lua/plenary.nvim',
            'nvim-neotest/neotest-go',
            'nvim-neotest/neotest-jest',
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
                jestConfigFile = 'jest.config.ts',
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
                    jest,
                },
            }
        end,

        config = function(_, opts)
        -- get neotest namespace (api call creates or returns namespace)
            local neotest_ns = vim.api.nvim_create_namespace 'neotest'
            vim.diagnostic.config({
                virtual_text = {
                    format = function(diagnostic)
                        local message = diagnostic.message:gsub('\n', ' '):gsub('\t', ' '):gsub('%s+', ' '):gsub('^%s+', '')
                        return message
                    end,
                },
            }, neotest_ns)

            require('neotest').setup(opts)
        end,
    },
    {
        'catppuccin/nvim',
        optional = true,
        opts = { integrations = { neotest = true } },
    },
}
