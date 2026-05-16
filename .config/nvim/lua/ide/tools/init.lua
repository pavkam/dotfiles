-- Tool definitions: registers all formatter and linter specs.
-- Called during IDE boot to populate FormatterRunner and LinterRunner registries
-- with the exact tools we use per filetype.
--
-- This replaces the configuration that was split between
-- lua/plugins/conform.lua and lua/plugins/nvim-lint.lua.

local M = {}

--- Register all formatter specs with the FormatterRunner.
---@param formatter FormatterRunner
function M.register_formatters(formatter)
    local function project_root() local p = IDE:project(); return p and p:root() or nil end

    -- Helper: wrap a spec into a single-element group (alternative list)
    local function alt(...) return { ... } end

    -- ── Lua ────────────────────────────────────────────────
    formatter:register('lua', {
        alt { cmd = 'stylua', args = { '--stdin-filepath', '$FILENAME', '-' }, stdin = true },
    })

    -- ── Shell ─────────────────────────────────────────────
    formatter:register('sh', {
        alt { cmd = 'shfmt', args = { '-' }, stdin = true },
    })

    -- ── JavaScript / TypeScript ───────────────────────────
    local js_groups = {
        alt(
            { cmd = 'prettierd', args = { '$FILENAME' }, stdin = true },
            { cmd = 'prettier', args = { '--stdin-filepath', '$FILENAME' }, stdin = true,
              cwd = function() return project_root() end }
        ),
        alt { cmd = 'eslint_d', args = { '--fix-to-stdout', '--stdin', '--stdin-filename', '$FILENAME' }, stdin = true },
    }
    formatter:register({ 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'vue' }, js_groups)

    -- ── Prettier-only filetypes ───────────────────────────
    local prettier_groups = {
        alt(
            { cmd = 'prettierd', args = { '$FILENAME' }, stdin = true },
            { cmd = 'prettier', args = { '--stdin-filepath', '$FILENAME' }, stdin = true,
              cwd = function() return project_root() end }
        ),
    }
    formatter:register({ 'markdown', 'html', 'css', 'scss', 'less', 'json', 'jsonc', 'yaml', 'graphql', 'handlebars' }, prettier_groups)

    -- ── Go ─────────────────────────────────────────────────
    formatter:register('go', {
        alt(
            { cmd = 'goimports-reviser', args = { '-' }, stdin = true,
              cwd = function() return project_root() end },
            { cmd = 'goimports', args = {}, stdin = true }
        ),
        alt(
            { cmd = 'golines', args = { '-m', '180', '--no-reformat-tags', '--base-formatter', 'gofumpt' }, stdin = true },
            { cmd = 'gofumpt', args = {}, stdin = true }
        ),
    })

    -- ── Python ─────────────────────────────────────────────
    formatter:register('python', {
        alt { cmd = 'black', args = { '--stdin-filename', '$FILENAME', '-' }, stdin = true },
        alt { cmd = 'isort', args = { '--stdout', '--filename', '$FILENAME', '-' }, stdin = true },
    })

    -- ── C# ────────────────────────────────────────────────
    formatter:register('cs', {
        alt { cmd = 'csharpier', args = { '--write-stdout' }, stdin = true },
    })

    -- ── Protobuf ──────────────────────────────────────────
    formatter:register('proto', {
        alt { cmd = 'buf', args = { 'format', '-' }, stdin = true },
    })

    -- ── Prisma ────────────────────────────────────────────
    formatter:register('prisma', {
        alt {
            cmd = function()
                return (IDE:project() and IDE:project():js_bin('prisma')) or 'prisma'
            end,
            args = { 'format', '--schema', '$FILENAME' },
            stdin = false,
            cwd = function() return project_root() end,
        },
    })
end

--- Register all linter specs with the LinterRunner.
---@param linter LinterRunner
function M.register_linters(linter)
    local function project_root() local p = IDE:project(); return p and p:root() or nil end

    local severity = vim.diagnostic.severity

    -- ── Lua ────────────────────────────────────────────────
    linter:register('lua', {
        {
            cmd = 'luacheck',
            args = { '--formatter', 'plain', '--codes', '--ranges', '-' },
            stdin = true,
            ignore_exitcode = true,
            source = 'luacheck',
            parse_fn = function(output, _bufnr)
                local diagnostics = {}
                for line in output:gmatch('[^\n]+') do
                    -- stdin:10:5-15: (W111) ...
                    local lnum, col_start, col_end, code, msg =
                        line:match('^[^:]+:(%d+):(%d+)%-(%d+):%s+%((%w+)%)%s+(.+)')
                    if lnum then
                        local sev = code:sub(1, 1) == 'E' and severity.ERROR or severity.WARN
                        diagnostics[#diagnostics + 1] = {
                            source = 'luacheck',
                            lnum = tonumber(lnum) - 1,
                            col = tonumber(col_start) - 1,
                            end_col = tonumber(col_end),
                            severity = sev,
                            message = msg,
                            code = code,
                        }
                    end
                end
                return diagnostics
            end,
        },
    })

    -- ── Shell ─────────────────────────────────────────────
    linter:register('sh', {
        {
            cmd = 'shellcheck',
            args = { '--format=json', '-' },
            stdin = true,
            ignore_exitcode = true,
            source = 'shellcheck',
            parse_fn = function(output, _bufnr)
                local ok, data = pcall(vim.json.decode, output, { luanil = { object = true, array = true } })
                if not ok or not data then return {} end

                local diagnostics = {}
                local sev_map = {
                    error = severity.ERROR,
                    warning = severity.WARN,
                    info = severity.INFO,
                    style = severity.HINT,
                }
                for _, item in ipairs(data) do
                    diagnostics[#diagnostics + 1] = {
                        source = 'shellcheck',
                        lnum = (item.line or 1) - 1,
                        col = (item.column or 1) - 1,
                        end_lnum = (item.endLine or item.line or 1) - 1,
                        end_col = (item.endColumn or item.column or 1) - 1,
                        severity = sev_map[item.level] or severity.WARN,
                        message = item.message or '',
                        code = item.code and ('SC' .. item.code) or nil,
                    }
                end
                return diagnostics
            end,
        },
    })

    -- ── JavaScript / TypeScript (eslint) ──────────────────
    local eslint_severities = { severity.WARN, severity.ERROR }

    linter:register({ 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }, {
        {
            cmd = function()
                return (IDE:project() and IDE:project():js_bin('eslint')) or 'eslint'
            end,
            args = { '--format', 'json', '--stdin', '--stdin-filename', '$FILENAME' },
            stdin = true,
            ignore_exitcode = true,
            source = 'eslint',
            condition = function(buf)
                local path = buf:path()
                if not path then return false end
                local dir = IDE.fs:dirname(path)
                local proj = IDE:project()
                return proj ~= nil and proj:js_has_dependency('eslint') and proj:eslint_config() ~= nil
            end,
            parse_fn = function(output, bufnr)
                local ok, data = pcall(vim.json.decode, output, { luanil = { object = true, array = true } })
                if not ok or not data then return {} end

                local diagnostics = {}
                local current_file = Buffer.is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) or ''

                for _, item in ipairs(data) do
                    if item.filePath == current_file then
                        for _, diagnostic in ipairs(item.messages or {}) do
                            diagnostics[#diagnostics + 1] = {
                                source = 'eslint',
                                lnum = (diagnostic.line or 1) - 1,
                                col = (diagnostic.column or 1) - 1,
                                end_lnum = (diagnostic.endLine or diagnostic.line or 1) - 1,
                                end_col = (diagnostic.endColumn or diagnostic.column or 1) - 1,
                                severity = eslint_severities[diagnostic.severity] or severity.WARN,
                                message = diagnostic.message or '',
                                code = diagnostic.ruleId,
                            }
                        end
                    end
                end
                return diagnostics
            end,
        },
    })

    -- ── JSON ──────────────────────────────────────────────
    linter:register('json', {
        {
            cmd = 'jsonlint',
            args = { '--compact', '-' },
            stdin = true,
            ignore_exitcode = true,
            source = 'jsonlint',
            parse_fn = function(output, _bufnr)
                local diagnostics = {}
                -- jsonlint error format: "line X, col Y, ..."
                for line in output:gmatch('[^\n]+') do
                    local lnum, col, msg = line:match('[Ll]ine%s+(%d+),%s+col%s+(%d+),%s+(.+)')
                    if lnum then
                        diagnostics[#diagnostics + 1] = {
                            source = 'jsonlint',
                            lnum = tonumber(lnum) - 1,
                            col = tonumber(col) - 1,
                            severity = severity.ERROR,
                            message = msg,
                        }
                    end
                end
                return diagnostics
            end,
        },
    })

    -- ── Go ─────────────────────────────────────────────────
    linter:register('go', {
        {
            cmd = 'golangci-lint',
            args = function(buf)
                local path = buf:path()
                local dir = path and IDE.fs:dirname(path) or '.'
                return { 'run', '--fast', '--out-format', 'json', dir }
            end,
            stdin = false,
            ignore_exitcode = true,
            source = 'golangci-lint',
            condition = function(buf)
                local proj = IDE:project()
                if not proj then return false end
                -- Only run if a golangci config exists in the project
                for _, name in ipairs({
                    '.golangci.yml', '.golangci.yaml',
                    '.golangci.toml', '.golangci.json',
                }) do
                    if proj:has_file(name) then return true end
                end
                return false
            end,
            parse_fn = function(output, _bufnr)
                local ok, data = pcall(vim.json.decode, output, { luanil = { object = true, array = true } })
                if not ok or not data or not data.Issues then return {} end

                local diagnostics = {}
                for _, issue in ipairs(data.Issues) do
                    local pos = issue.Pos or {}
                    diagnostics[#diagnostics + 1] = {
                        source = 'golangci-lint',
                        lnum = (pos.Line or 1) - 1,
                        col = (pos.Column or 1) - 1,
                        severity = severity.WARN,
                        message = issue.Text or '',
                        code = issue.FromLinter,
                    }
                end
                return diagnostics
            end,
        },
    })

    -- ── Protobuf ──────────────────────────────────────────
    linter:register('proto', {
        {
            cmd = 'buf',
            args = { 'lint', '$FILENAME' },
            stdin = false,
            ignore_exitcode = true,
            source = 'buf',
            parse_fn = function(output, _bufnr)
                local diagnostics = {}
                -- buf lint output: path:line:col:message
                for line in output:gmatch('[^\n]+') do
                    local _, lnum, col, msg = line:match('^([^:]+):(%d+):(%d+):(.+)')
                    if lnum then
                        diagnostics[#diagnostics + 1] = {
                            source = 'buf',
                            lnum = tonumber(lnum) - 1,
                            col = tonumber(col) - 1,
                            severity = severity.WARN,
                            message = vim.trim(msg),
                        }
                    end
                end
                return diagnostics
            end,
        },
    })

    -- ── Dockerfile ────────────────────────────────────────
    linter:register('dockerfile', {
        {
            cmd = 'hadolint',
            args = { '--format=json', '-' },
            stdin = true,
            ignore_exitcode = true,
            source = 'hadolint',
            parse_fn = function(output, _bufnr)
                local ok, data = pcall(vim.json.decode, output, { luanil = { object = true, array = true } })
                if not ok or not data then return {} end

                local diagnostics = {}
                local sev_map = {
                    error = severity.ERROR,
                    warning = severity.WARN,
                    info = severity.INFO,
                    style = severity.HINT,
                }
                for _, item in ipairs(data) do
                    diagnostics[#diagnostics + 1] = {
                        source = 'hadolint',
                        lnum = (item.line or 1) - 1,
                        col = (item.column or 1) - 1,
                        severity = sev_map[item.level] or severity.WARN,
                        message = item.message or '',
                        code = item.code,
                    }
                end
                return diagnostics
            end,
        },
    })

    -- ── Markdown ──────────────────────────────────────────
    linter:register('markdown', {
        {
            cmd = 'markdownlint',
            args = { '--stdin' },
            stdin = true,
            ignore_exitcode = true,
            source = 'markdownlint',
            parse_fn = function(output, _bufnr)
                local diagnostics = {}
                -- markdownlint output: stdin:line[:col] rule message
                for line in output:gmatch('[^\n]+') do
                    local lnum, rule, msg = line:match('^[^:]+:(%d+)%s+(MD%d+)%s+(.+)')
                    if not lnum then
                        lnum, _, rule, msg = line:match('^[^:]+:(%d+):(%d+)%s+(MD%d+)%s+(.+)')
                    end
                    if lnum then
                        diagnostics[#diagnostics + 1] = {
                            source = 'markdownlint',
                            lnum = tonumber(lnum) - 1,
                            col = 0,
                            severity = severity.WARN,
                            message = msg or '',
                            code = rule,
                        }
                    end
                end
                return diagnostics
            end,
        },
    })

    -- ── Python ─────────────────────────────────────────────
    linter:register('python', {
        {
            cmd = 'ruff',
            args = { 'check', '--output-format=json', '--stdin-filename', '$FILENAME', '-' },
            stdin = true,
            ignore_exitcode = true,
            source = 'ruff',
            parse_fn = function(output, _bufnr)
                local ok, data = pcall(vim.json.decode, output, { luanil = { object = true, array = true } })
                if not ok or not data then return {} end

                local diagnostics = {}
                for _, item in ipairs(data) do
                    local loc = item.location or {}
                    local end_loc = item.end_location or loc
                    diagnostics[#diagnostics + 1] = {
                        source = 'ruff',
                        lnum = (loc.row or 1) - 1,
                        col = (loc.column or 1) - 1,
                        end_lnum = (end_loc.row or loc.row or 1) - 1,
                        end_col = (end_loc.column or loc.column or 1) - 1,
                        severity = severity.WARN,
                        message = item.message or '',
                        code = item.code,
                    }
                end
                return diagnostics
            end,
        },
        {
            cmd = 'mypy',
            args = { '--show-column-numbers', '--show-error-codes', '--no-color-output',
                     '--no-error-summary', '--no-pretty', '$FILENAME' },
            stdin = false,
            ignore_exitcode = true,
            source = 'mypy',
            condition = function(buf)
                local proj = IDE:project()
                if not proj then return false end
                -- Only run if a mypy config or pyproject.toml exists
                return proj:has_file('mypy.ini')
                    or proj:has_file('.mypy.ini')
                    or proj:has_file('setup.cfg')
                    or proj:has_file('pyproject.toml')
            end,
            parse_fn = function(output, _bufnr)
                local diagnostics = {}
                local sev_map = {
                    error = severity.ERROR,
                    warning = severity.WARN,
                    note = severity.INFO,
                }
                for line in output:gmatch('[^\n]+') do
                    -- mypy output: file.py:line:col: severity: message  [code]
                    local lnum, col, sev_str, msg = line:match('^[^:]+:(%d+):(%d+):%s+(%w+):%s+(.+)')
                    if not lnum then
                        -- fallback: file.py:line: severity: message
                        lnum, sev_str, msg = line:match('^[^:]+:(%d+):%s+(%w+):%s+(.+)')
                        col = '1'
                    end
                    if lnum then
                        local code = msg:match('%[([%w%-]+)%]%s*$')
                        if code then
                            msg = msg:gsub('%s*%[' .. code:gsub('%-', '%%-') .. '%]%s*$', '')
                        end
                        diagnostics[#diagnostics + 1] = {
                            source = 'mypy',
                            lnum = tonumber(lnum) - 1,
                            col = tonumber(col) - 1,
                            severity = sev_map[sev_str] or severity.WARN,
                            message = msg,
                            code = code,
                        }
                    end
                end
                return diagnostics
            end,
        },
    })

    -- ── C# ────────────────────────────────────────────────
    linter:register('cs', {
        {
            cmd = 'csharpier',
            args = { '--check', '$FILENAME' },
            stdin = false,
            ignore_exitcode = true,
            source = 'csharpier',
            parse_fn = function(output, _bufnr)
                local diagnostics = {}
                -- csharpier --check outputs files that would be reformatted
                if output and vim.trim(output) ~= '' then
                    for line in output:gmatch('[^\n]+') do
                        if vim.trim(line) ~= '' then
                            diagnostics[#diagnostics + 1] = {
                                source = 'csharpier',
                                lnum = 0,
                                col = 0,
                                severity = severity.WARN,
                                message = 'File needs formatting: ' .. vim.trim(line),
                            }
                        end
                    end
                end
                return diagnostics
            end,
        },
    })
end

return M
