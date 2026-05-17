return {
    'nvim-neotest/neotest',
    ft = {
        'javascript',
        'typescript',
        'javascriptreact',
        'typescriptreact',
        'go',
    },
    dependencies = {
        'nvim-neotest/nvim-nio',
        'nvim-lua/plenary.nvim',
        'nvim-treesitter/nvim-treesitter',
        'nvim-neotest/neotest-jest',
        'marilari88/neotest-vitest',
        'fredrikaverpil/neotest-golang',
    },
    opts = function(_, opts)
        local jest = require 'neotest-jest'
        local vitest = require 'neotest-vitest'

        local function project_root()
            local p = IDE:project()
            return p and p:root() or vim.uv.cwd()
        end

        jest = jest {
            jestCommand = function()
                local p = IDE:project()
                return p and p:js_bin('jest') or 'jest'
            end,
            cwd = function() return project_root() end,
        }

        vitest = vitest {
            vitestCommand = function()
                local p = IDE:project()
                return p and p:js_bin('vitest') or 'vitest'
            end,
            cwd = function() return project_root() end,
        }

        local go_lang = require 'neotest-golang'

        opts.adapters = {
            go_lang,
            vitest,
            jest,
        }

        return opts
    end,
    config = function(_, opts)
        -- Register neotest virtual text diagnostics namespace
        local neotest_ns = vim.api.nvim_create_namespace 'neotest'
        vim.diagnostic.config({
            virtual_text = {
                format = function(diagnostic)
                    return diagnostic.message:gsub('\n', ' '):gsub('\t', ' '):gsub('%s+', ' '):gsub('^%s+', '')
                end,
            },
        }, neotest_ns)

        -- Keymaps are handled by ide/extensions/test_runner.lua
        -- (avoids duplication and uses IDE abstractions)

        require('neotest').setup(opts)
    end,
}
