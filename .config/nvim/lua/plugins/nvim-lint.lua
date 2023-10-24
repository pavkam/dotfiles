return {
    "mfussenegger/nvim-lint",
    event = "User NormalFile",
    keys = {
        {
            "<leader>ul",
            function()
                require("utils.lint").toggle_for_buffer()
            end,
            mode = { "n" },
            desc = "Toggle buffer auto-linting",
        },
        {
            "<leader>uL",
            function()
                require("utils.lint").toggle()
            end,
            mode = { "n" },
            desc = "Toggle global auto-linting",
        },
    },
    opts = function()
        local js_project = require "utils.project.js"
        local js_project = require "utils.project.js"

        local eslint_severities = {
            vim.diagnostic.severity.WARN,
            vim.diagnostic.severity.ERROR,
        }

        return {
            linters_by_ft = {
                lua = { "luacheck" },
                sh = { "shellcheck" },
                javascript = { "eslint" },
                javascriptreact = { "eslint" },
                typescript = { "eslint" },
                typescriptreact = { "eslint" },
                go = { "golangcilint" },
                proto = { "buf_lint" },
                dockerfile = { "hadolint" },
                markdown = { "markdownlint" },
            },
            linters = {
                golangcilint = {
                    args = {
                        'run',
                        '--fast',
                        '--out-format',
                        'json',
                        function()
                            return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":h")
                        end
                    },
                },
                eslint = {
                    cmd = function()
                        return js_project.get_bin_path(nil, "eslint")
                    end,
                    condition = function(ctx)
                        return js_project.has_dependency(ctx.dirname, "eslint") and js_project.get_eslint_config_path(ctx.dirname)
                    end,
                    args = {
                        '--format',
                        'json',
                        '--stdin',
                        '--stdin-filename',
                        function() return vim.api.nvim_buf_get_name(0) end,
                    },
                    parser = function(output, buffer)
                        local success, data = pcall(vim.json.decode, output, { luanil = { object = true, array = true } })
                        local diagnostics = {}

                        for _, item in ipairs(data) do
                            local current_file = vim.api.nvim_buf_get_name(buffer)
                            local linted_file = item.filePath

                            if current_file == linted_file then
                                for _, diagnostic in ipairs(item.messages or {}) do
                                    table.insert(diagnostics, {
                                        source = "eslint",
                                        lnum = diagnostic.line - 1,
                                        col = diagnostic.column - 1,
                                        end_lnum = (diagnostic.endLine or diagnostic.line) - 1,
                                        end_col = (diagnostic.endColumn or diagnostic.column) - 1,
                                        severity = eslint_severities[diagnostic.severity],
                                        message = diagnostic.message,
                                        code = diagnostic.ruleId
                                    })
                                end
                            end
                        end

                        return diagnostics
                    end
                },
            },
        }
    end,
    config = function(_, opts)
        local utils = require "utils"
        local lint = require "lint"

        -- apply user options to the default config
        for name, linter in pairs(opts.linters) do
            if type(linter) == "table" and type(lint.linters[name]) == "table" then
                local args = linter.args
                linter.args = nil

                lint.linters[name] = utils.tbl_merge(lint.linters[name], linter)

                if args then
                    lint.linters[name].args = args
                end
            else
                lint.linters[name] = linter
            end
        end

        -- setup my linters
        lint.linters_by_ft = opts.linters_by_ft

        -- setup auto-commands
        utils.on_event(
            { "BufWritePost", "BufReadPost", "InsertLeave" },
            function(evt) require("utils.lint").apply(evt.buf) end,
            "*"
        )
    end,
}
