return {
    'stevearc/conform.nvim',
    cmd = 'ConformInfo',
    keys = {
        {
            '<leader>sj',
            function()
                require('utils.format').apply(nil, true, true)
            end,
            mode = { 'n', 'v' },
            desc = 'Format buffer injected',
        },
        {
            '<leader>sf',
            function()
                require('utils.format').apply(nil, true)
            end,
            mode = { 'n', 'v' },
            desc = 'Format buffer',
        },
        {
            '<leader>uf',
            function()
                require('utils.format').toggle_for_buffer()
            end,
            mode = { 'n' },
            desc = 'Toggle buffer auto-formatting',
        },
        {
            '<leader>uF',
            function()
                require('utils.format').toggle()
            end,
            mode = { 'n' },
            desc = 'Toggle global auto-formatting',
        },
    },
    init = function()
        vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
    opts = function()
        local utils = require 'utils'
        local project = require 'utils.project'

        return {
            formatters_by_ft = {
                lua = { 'stylua' },
                sh = { 'shfmt' },
                javascript = { { 'prettier', 'prettierd' } },
                javascriptreact = { { 'prettier', 'prettierd' } },
                typescript = { { 'prettier', 'prettierd' } },
                typescriptreact = { { 'prettier', 'prettierd' } },
                go = { { 'goimports-reviser', 'goimports' }, { 'golines', 'gofumpt' } },
                csharp = { 'csharpier' },
                python = { 'black', 'isort' },
                proto = { 'buf' },
                markdown = { { 'prettier', 'prettierd' } },
                html = { { 'prettier', 'prettierd' } },
                css = { { 'prettier', 'prettierd' } },
                scss = { { 'prettier', 'prettierd' } },
                less = { { 'prettier', 'prettierd' } },
                vue = { { 'prettier', 'prettierd' } },
                json = { { 'prettier', 'prettierd' } },
                jsonc = { { 'prettier', 'prettierd' } },
                yaml = { { 'prettier', 'prettierd' } },
                graphql = { { 'prettier', 'prettierd' } },
                handlebars = { { 'prettier', 'prettierd' } },
            },
            formatters = {
                ['goimports-reviser'] = {
                    cwd = function(ctx)
                        return project.root(ctx.buf or ctx.filename)
                    end,
                },
                prettier = {
                    cwd = function(ctx)
                        return project.root(ctx.buf or ctx.filename)
                    end,
                },
                golines = utils.tbl_merge(require 'conform.formatters.golines', {
                    args = { '-m', '180', '--no-reformat-tags', '--base-formatter', 'gofumpt' },
                }),
            },
        }
    end,
    config = function(_, opts)
        local conform = require 'conform'
        conform.setup(opts)

        local utils = require 'utils'

        utils.on_event('BufWritePre', function(evt)
            require('utils.format').apply(evt.buf)
        end, '*')
    end,
}
