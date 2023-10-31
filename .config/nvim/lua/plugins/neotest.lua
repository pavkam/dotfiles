return {
    'nvim-neotest/neotest',
    --commit = "455155f65e3397022a7b23cc3e152b43a6fc5d23",
    ft = {
        'javascript',
        'typescript',
        'javascriptreact',
        'typescriptreact',
        'go',
    },
    dependencies = {
        'nvim-treesitter/nvim-treesitter',
        'nvim-neotest/neotest-jest',
        'marilari88/neotest-vitest',
        'nvim-neotest/neotest-go',
    },
    opts = function(_, opts)
        local utils = require 'utils'
        local project = require 'utils.project'
        local jest = require 'neotest-jest'
        local vitest = require 'neotest-vitest'

        jest = jest {
            cwd = function(path)
                return project.root(path)
            end,
        }

        vitest = vitest {
            cwd = function(path)
                return project.root(path)
            end,
        }

        opts.adapters = utils.list_insert_unique(opts.adapters, {
            require 'neotest-go',
            vitest,
            jest,
        })

        return opts
    end,
    config = function(spec, opts)
        local utils = require 'utils'

        -- register neotest virtual text
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
            buffer = buffer or vim.api.nvim_get_current_buf()

            if vim.bo[buffer].modified then
                local choice = vim.fn.confirm(
                    string.format('Save changes to %q before running tests?', vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ':h')),
                    '&Yes\n&No\n&Cancel'
                )

                if choice == 3 then
                    return false
                end

                if choice == 1 then
                    vim.api.nvim_buf_call(buffer, vim.cmd.write)
                end
            end

            return true
        end

        -- register neotest mappings
        utils.on_event('FileType', function(args)
            local icons = require 'utils.icons'
            local neotest = require 'neotest'

            vim.keymap.set('n', '<leader>tU', function()
                neotest.summary.toggle()
            end, { buffer = args.buf, desc = 'Toggle summary view' })

            vim.keymap.set('n', '<leader>to', function()
                neotest.output.open()
            end, { buffer = args.buf, desc = 'Show test output' })

            vim.keymap.set('n', '<leader>tw', function()
                neotest.watch.toggle()
            end, { buffer = args.buf, desc = 'Togglee test watching' })

            vim.keymap.set('n', '<leader>tf', function()
                neotest.run.run(vim.fn.expand '%')
            end, { buffer = args.buf, desc = 'Run all tests' })

            vim.keymap.set('n', '<leader>tr', function()
                if not confirm_saved() then
                    return
                end

                neotest.run.run()
            end, { buffer = args.buf, desc = 'Run nearest test' })

            vim.keymap.set('n', '<leader>td', function()
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
            require('which-key').register({
                ['<leader>t'] = { name = icons.UI.Test .. ' Testing' },
            }, { buffer = args.buf })
        end, spec.ft)

        require('neotest').setup(opts)
    end,
}
