return {
    'stevearc/conform.nvim',
    cond = feature_level(3),
    cmd = 'ConformInfo',
    keys = {
        {
            '<leader>sj',
            function()
                require('formatting').apply(nil, true)
            end,
            mode = { 'n', 'v' },
            desc = 'Format buffer injected',
        },
        {
            '<leader>sf',
            function()
                require('formatting').apply()
            end,
            mode = { 'n', 'v' },
            desc = 'Format buffer',
        },
        {
            '<leader>uf',
            function()
                require('core.toggles').toggle_auto_formatting { buffer = vim.api.nvim_get_current_buf() }
            end,
            mode = { 'n' },
            desc = 'Toggle buffer auto-formatting',
        },
        {
            '<leader>uF',
            function()
                require('core.toggles').toggle_auto_formatting()
            end,
            mode = { 'n' },
            desc = 'Toggle global auto-formatting',
        },
    },
    init = function()
        vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
    opts = function()
        local utils = require 'core.utils'
        local project = require 'project'

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
                prisma = { 'prisma' },
            },
            formatters = {
                ['goimports-reviser'] = {
                    ---@diagnostic disable-next-line: unused-local
                    cwd = function(self, ctx)
                        return project.root(ctx.buf or ctx.filename)
                    end,
                },
                prettier = {
                    ---@diagnostic disable-next-line: unused-local
                    cwd = function(self, ctx)
                        return project.root(ctx.buf or ctx.filename)
                    end,
                },
                golines = utils.tbl_merge(require 'conform.formatters.golines', {
                    args = { '-m', '180', '--no-reformat-tags', '--base-formatter', 'gofumpt' },
                }),
                prisma = {
                    ---@diagnostic disable-next-line: unused-local
                    cwd = function(self, ctx)
                        return project.root(ctx.buf or ctx.filename)
                    end,
                    meta = {
                        url = 'https://github.com/prisma/prisma-engines',
                        description = 'Formatter for the prisma filetype.',
                    },
                    ---@diagnostic disable-next-line: unused-local
                    command = function(self, ctx)
                        return project.get_js_bin_path(ctx.buf or ctx.filename, 'prisma') or 'prisma'
                    end,
                    stdin = false,
                    args = { 'format', '--schema', '$FILENAME' },
                },
            },
        }
    end,
    config = function(_, opts)
        local conform = require 'conform'
        local settings = require 'core.settings'
        local utils = require 'core.utils'

        conform.setup(opts)

        utils.on_event('BufWritePre', function(evt)
            if settings.global.auto_formatting_enabled and settings.buf[evt.buf].auto_formatting_enabled then
                require('formatting').apply(evt.buf)
            end
        end, '*')
    end,
}
