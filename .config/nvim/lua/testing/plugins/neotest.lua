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
        'nvim-neotest/neotest-go',
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

        opts.adapters = {
            require 'neotest-go',
            vitest,
            jest,
        }

        opts.consumers = vim.tbl_extend('force', opts.consumers or {}, {
            progress = require 'testing.neotest-progress-consumer',
        })

        return opts
    end,
    config = function(spec, opts)
        local utils = require 'core.utils'
        local keys = require 'core.keys'

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

        local function confirm_saved(buffer)
            return require('core.utils').confirm_saved(buffer, 'running tests')
        end

        -- register neotest mappings
        utils.on_event('FileType', function(args)
            local icons = require 'ui.icons'
            local neotest = require 'neotest'

            keys.map('n', '<leader>tU', function()
                neotest.summary.toggle()
            end, { buffer = args.buf, desc = 'Toggle summary view' })

            keys.map('n', '<leader>to', function()
                neotest.output.open()
            end, { buffer = args.buf, desc = 'Show test output' })

            keys.map('n', '<leader>tw', function()
                neotest.watch.toggle()
            end, { buffer = args.buf, desc = 'Toggle test watching' })

            keys.map('n', '<leader>tf', function()
                neotest.run.run(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
            end, { buffer = args.buf, desc = 'Run all tests' })

            keys.map('n', '<leader>tr', function()
                if not confirm_saved() then
                    return
                end

                neotest.run.run()
            end, { buffer = args.buf, desc = 'Run nearest test' })

            keys.map('n', '<leader>td', function()
                if not confirm_saved() then
                    return
                end

                if args.match == 'go' then
                    require('dap-go').debug_test()
                else
                    require('neotest').run.run { strategy = 'dap', suite = false }
                end
            end, { buffer = args.buf, desc = 'Debug nearest test' })

            -- add which key group
            require('which-key').add({
                desc = '<leader>t',
                icon = icons.UI.Test,
                group = 'Testing',
            }, { buffer = args.buf })
        end, spec.ft)

        local neotest = require 'neotest'
        neotest.setup(opts)
    end,
}
