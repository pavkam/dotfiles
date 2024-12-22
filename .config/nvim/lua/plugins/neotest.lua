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
        local project = require 'project'
        local jest = require 'neotest-jest'
        local vitest = require 'neotest-vitest'

        jest = jest {
            jestCommand = function(path)
                return project.get_js_bin_path(path, 'jest')
            end,
            cwd = function(path)
                return project.root(path)
            end,
        }

        vitest = vitest {
            vitestCommand = function(path)
                return project.get_js_bin_path(path, 'vitest')
            end,
            cwd = function(path)
                return project.root(path)
            end,
        }

        local go_lang = require 'neotest-golang'

        opts.adapters = {
            go_lang,
            vitest,
            jest,
        }

        opts.consumers = vim.tbl_extend('force', opts.consumers or {}, {
            progress = require 'neotest-progress-consumer',
        })

        return opts
    end,
    config = function(spec, opts)
        local keys = require 'keys'

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
            return ide.buf.current.confirm_saved 'running tests'
        end

        -- register neotest mappings
        keys.attach(spec.ft, function(set, file_type, buffer)
            local icons = require 'icons'
            local neotest = require 'neotest'

            set('n', '<leader>tU', function()
                neotest.summary.toggle()
            end, { desc = 'Toggle summary view' })

            set('n', '<leader>to', function()
                neotest.output.open()
            end, { desc = 'Show test output' })

            set('n', '<leader>tw', function()
                neotest.watch.toggle()
            end, { desc = 'Toggle test watching' })

            set('n', '<leader>tf', function()
                neotest.run.run(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
            end, { desc = 'Run all tests' })

            set('n', '<leader>tr', function()
                if not confirm_saved() then
                    return
                end

                neotest.run.run()
            end, { desc = 'Run nearest test' })

            set('n', '<leader>td', function()
                if not confirm_saved() then
                    return
                end

                if file_type == 'go' then
                    require('dap-go').debug_test()
                else
                    require('neotest').run.run { strategy = 'dap', suite = false }
                end
            end, { desc = 'Debug nearest test' })

            -- add which key group
            keys.group {
                mode = 'n',
                lhs = '<leader>t',
                icon = icons.UI.Test,
                desc = 'Testing',
                buffer = buffer,
            }
        end)

        local neotest = require 'neotest'
        neotest.setup(opts)
    end,
}
