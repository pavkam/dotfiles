local astro_utils = require 'astronvim.utils'

return {
    {
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
    },
}
