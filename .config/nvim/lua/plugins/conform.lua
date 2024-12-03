return {
    'stevearc/conform.nvim',
    cond = not vim.headless,
    cmd = 'ConformInfo',
    init = function()
        vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
    opts = function()
        local project = require 'project'
        local conform = require 'conform'

        --- Creates a group of formatters
        ---@param ... string[] # the formatters to group
        local function select(...)
            local formatter_groups = { ... }

            return function(buffer)
                local formatters = vim.iter(formatter_groups)
                    :map(
                        ---@param group string[]
                        function(group)
                            for _, formatter in pairs(group) do
                                if conform.get_formatter_info(formatter, buffer).available then
                                    return formatter
                                end
                            end
                            return nil
                        end
                    )
                    :filter(function(formatter)
                        return formatter
                    end)
                    :totable()

                vim.list_extend(formatters, { 'injected' })
                return formatters
            end
        end

        local prettier = select { 'prettierd', 'prettier' }
        local js = select({ 'prettierd', 'prettier' }, { 'eslint_d' })

        return {
            formatters_by_ft = {
                lua = select { 'stylua' },
                sh = select { 'shfmt' },
                javascript = js,
                javascriptreact = js,
                typescript = js,
                typescriptreact = js,
                go = select({ 'goimports-reviser', 'goimports' }, { 'golines', 'gofumpt' }),
                csharp = select { 'csharpier' },
                python = select({ 'black' }, { 'isort' }),
                proto = select { 'buf' },
                markdown = prettier,
                html = prettier,
                css = prettier,
                scss = prettier,
                less = prettier,
                vue = js,
                json = prettier,
                jsonc = prettier,
                yaml = prettier,
                graphql = prettier,
                handlebars = prettier,
                prisma = select { 'prisma' },
            },
            formatters = {
                ['goimports-reviser'] = {
                    cwd = function(_, ctx)
                        return project.root(ctx.buf or ctx.filename)
                    end,
                },
                prettier = {
                    cwd = function(_, ctx)
                        return project.root(ctx.buf or ctx.filename)
                    end,
                },
                golines = table.merge(require 'conform.formatters.golines', {
                    args = { '-m', '180', '--no-reformat-tags', '--base-formatter', 'gofumpt' },
                }),
                prisma = {
                    cwd = function(_, ctx)
                        return project.root(ctx.buf or ctx.filename)
                    end,
                    meta = {
                        url = 'https://github.com/prisma/prisma-engines',
                        description = 'Formatter for the prisma filetype.',
                    },
                    command = function(_, ctx)
                        return project.get_js_bin_path(ctx.buf or ctx.filename, 'prisma') or 'prisma'
                    end,
                    stdin = false,
                    args = { 'format', '--schema', '$FILENAME' },
                },
            },
        }
    end,
}
