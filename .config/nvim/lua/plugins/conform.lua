return {
    'stevearc/conform.nvim',
    cond = not ide.process.is_headless,
    init = function()
        vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
        ---@module 'conform'
        local conform = xrequire 'conform'

        ---@type table<integer, boolean>
        local running_for_buffers = {}
        ide.plugin.register_formatter {
            ---@param buffer buffer
            ---@return table<string, boolean>
            status = function(buffer)
                xassert {
                    buffer = { buffer, 'table' },
                }

                local ok, clients = pcall(conform.list_formatters, buffer.id)

                if not ok then
                    return {}
                end

                local status = {}
                for _, client in pairs(clients) do
                    status[client.name] = running_for_buffers[buffer.id] or false
                end

                return status
            end,
            run = function(buffer, callback)
                xassert {
                    buffer = { buffer, 'table' },
                    callback = { callback, 'callable' },
                }

                local ok, clients = pcall(conform.list_formatters, buffer.id)

                if not ok then
                    callback(false)
                    return
                end

                if #clients > 0 then
                    running_for_buffers[buffer.id] = true
                    conform.format({
                        bufnr = buffer.id,
                        formatters = table.list_map(clients, function(v)
                            return v.name
                        end),
                        quiet = true,
                        lsp_format = 'fallback',
                        timeout_ms = 5000,
                    }, function(err, edited)
                        running_for_buffers[buffer.id] = nil
                        if err then
                            callback(err)
                        else
                            callback(edited or false)
                        end
                    end)
                end
            end,
        }
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
