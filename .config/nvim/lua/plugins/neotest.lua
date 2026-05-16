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

        -- neotest-progress-consumer was removed (absorbed)

        return opts
    end,
    config = function(spec, opts)
        -- register neo-test virtual text
        local neotest_ns = vim.api.nvim_create_namespace 'neotest'
        vim.diagnostic.config({
            virtual_text = {
                format = function(diagnostic)
                    local message = diagnostic.message:gsub('\n', ' '):gsub('\t', ' '):gsub('%s+', ' '):gsub('^%s+', '')
                    return message
                end,
            },
        }, neotest_ns)

        local function confirm_saved()
            local buf = IDE.buffers:current()
            if buf:is_modified() then buf:save() end
            return true
        end

        -- register neotest mappings via IDE KeyManager
        IDE.keys:attach(spec.ft, function(set)
            local neotest = require 'neotest'

            set('n', '<leader>tU', function() neotest.summary.toggle() end, { desc = 'Toggle summary view' })
            set('n', '<leader>to', function() neotest.output.open() end, { desc = 'Show test output' })
            set('n', '<leader>tw', function() neotest.watch.toggle() end, { desc = 'Toggle test watching' })
            set('n', '<leader>tf', function()
                neotest.run.run(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
            end, { desc = 'Run all tests' })
            set('n', '<leader>tr', function()
                if confirm_saved() then neotest.run.run() end
            end, { desc = 'Run nearest test' })
            set('n', '<leader>td', function()
                if not confirm_saved() then return end
                local ft = vim.bo.filetype
                if ft == 'go' then
                    require('dap-go').debug_test()
                else
                    neotest.run.run { strategy = 'dap', suite = false }
                end
            end, { desc = 'Debug nearest test' })
        end, true)

        IDE.keys:group('<leader>t', { desc = 'Testing' })

        local neotest = require 'neotest'
        neotest.setup(opts)
    end,
}
