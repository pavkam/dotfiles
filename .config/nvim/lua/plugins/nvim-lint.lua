return {
    'mfussenegger/nvim-lint',
    cond = not ide.process.is_headless,
    opts = function()
        local project = require 'project'
        local eslint_severities = {
            vim.diagnostic.severity.WARN,
            vim.diagnostic.severity.ERROR,
        }

        return {
            linters_by_ft = {
                lua = { 'luacheck' },
                sh = { 'shellcheck' },
                javascript = { 'eslint' },
                javascriptreact = { 'eslint' },
                typescript = { 'eslint' },
                typescriptreact = { 'eslint' },
                json = { 'jsonlint' },
                go = { 'golangcilint' },
                proto = { 'buf_lint' },
                dockerfile = { 'hadolint' },
                markdown = { 'markdownlint' },
                python = { 'flake8' },
                csharp = { 'csharpier' },
            },
            linters = {
                golangcilint = {
                    args = {
                        'run',
                        '--fast',
                        '--out-format',
                        'json',
                        function()
                            return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':h')
                        end,
                    },
                },
                eslint = {
                    cmd = function()
                        return project.get_js_bin_path(nil, 'eslint') or 'eslint'
                    end,
                    condition = function(ctx)
                        return project.js_has_dependency(ctx.dirname, 'eslint')
                            and project.get_eslint_config_path(ctx.dirname) ~= nil
                    end,
                    args = {
                        '--format',
                        'json',
                        '--stdin',
                        '--stdin-filename',
                        function()
                            return vim.api.nvim_buf_get_name(0)
                        end,
                    },
                    parser = function(output, buffer)
                        local success, data =
                            pcall(vim.json.decode, output, { luanil = { object = true, array = true } })
                        local diagnostics = {}

                        if not success then
                            return diagnostics
                        end

                        for _, item in ipairs(data or {}) do
                            local current_file = vim.api.nvim_buf_get_name(buffer)
                            local linted_file = item.filePath

                            if current_file == linted_file then
                                for _, diagnostic in ipairs(item.messages or {}) do
                                    table.insert(diagnostics, {
                                        source = 'eslint',
                                        lnum = (diagnostic.line or 1) - 1,
                                        col = (diagnostic.column or 1) - 1,
                                        end_lnum = (diagnostic.endLine or diagnostic.line or 1) - 1,
                                        end_col = (diagnostic.endColumn or diagnostic.column or 1) - 1,
                                        severity = eslint_severities[diagnostic.severity],
                                        message = diagnostic.message,
                                        code = diagnostic.ruleId,
                                    })
                                end
                            end
                        end

                        return diagnostics
                    end,
                },
            },
        }
    end,
    config = function(_, opts)
        local lint = require 'lint'

        -- apply user options to the default config
        for name, linter in pairs(opts.linters) do
            if type(linter) == 'table' and type(lint.linters[name]) == 'table' then
                local args = linter.args
                linter.args = nil

                local linter_def = lint.linters[name]
                if type(linter_def) ~= 'table' then
                    error('linter ' .. name .. ' is defined as function, cannot override!')
                end

                ---@cast linter_def lint.Linter
                lint.linters[name] = table.merge(linter_def, linter)

                if args then
                    lint.linters[name].args = args
                end
            else
                lint.linters[name] = linter
            end
        end

        -- setup my linters
        lint.linters_by_ft = opts.linters_by_ft
    end,
    init = function()
        local lint = xrequire 'lint'

        local poll_time = 100

        local debounced_lint = ide.sched.debounce(
            ---@param buffer buffer
            ---@param names string[]
            ---@param callback fun()
            function(buffer, names, callback)
                lint.try_lint(names, { cwd = buffer.root })
                callback()
            end,
            poll_time
        )

        ---@param buffer buffer
        local function get_linters(buffer)
            xassert {
                buffer = { buffer, 'table' },
            }

            if not buffer.file_type or not buffer.file_path then
                return {}
            end

            local clients = lint.linters_by_ft[buffer.file_type] or {}

            local ctx = {
                filename = buffer.file_path,
                dirname = ide.fs.directory_name(buffer.file_path),
                buf = buffer.id,
            }

            ---@class (exact) lint.LinterEx: lint.Linter
            ---@field condition nil|fun(ctx: table<string, any>): boolean

            return table.list_filter(clients, function(name)
                local linter = lint.linters[name] --[[@as lint.LinterEx|fun():lint.LinterEx]]

                if type(linter) == 'function' then
                    linter = linter()
                end

                if type(linter) == 'table' and linter.condition then
                    return linter.condition(ctx)
                end

                return linter
            end)
        end

        ide.plugin.register_linter {
            ---@param buffer buffer
            status = function(buffer)
                local all = get_linters(buffer)
                local running = lint.get_running(buffer.id)

                ---@type table<string, boolean>
                local result = {}

                for _, name in ipairs(all) do
                    result[name] = table.list_any(running, name)
                end

                return result
            end,
            run = function(buffer, callback)
                xassert {
                    buffer = { buffer, 'table' },
                    callback = { callback, 'callable' },
                }

                -- check if we have any linters for this fie type
                local names = get_linters(buffer)
                if #names == 0 then
                    return
                end

                debounced_lint(buffer, names, function()
                    ide.sched.poll(function()
                        local running = require('lint').get_running(buffer.id)
                        if #running == 0 then
                            callback(true)
                        else
                            return true
                        end
                    end, poll_time)
                end)
            end,
        }
    end,
}
