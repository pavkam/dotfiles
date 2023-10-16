
return {
    "stevearc/conform.nvim",
    cmd = "ConformInfo",
    keys = {
        {
            "<leader>sj",
            function()
                local format = require "utils.format"
                format.apply(nil, true)
            end,
            mode = { "n", "v" },
            desc = "Format Buffer Injected",
        },
        {
            "<leader>sf",
            function()
                local format = require "utils.format"
                format.apply(nil)
            end,
            mode = { "n", "v" },
            desc = "Format Buffer",
        },
        {
            "<leader>uf",
            function()
                require("utils.format").toggle_for_buffer()
            end,
            mode = { "n" },
            desc = "Toggle Auto-Formatting (Buffer)",
        },
        {
            "<leader>uF",
            function()
                require("utils.format").toggle()
            end,
            mode = { "n" },
            desc = "Toggle Auto-Formatting (Global)",
        },
    },
    init = function()
        vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
    opts = function()
        local utils = require "utils"
        local project = require "utils.project"
        local js_project = require "utils.project.js"

        return {
            formatters_by_ft = {
                lua = { "stylua" },
                sh = { "shfmt" },
                javascript = { { "prettier", "prettierd" } },
                javascriptreact = { { "prettier", "prettierd" } },
                typescript = { { "prettied", "prettierd" } },
                typescriptreact = { { "prettier", "prettierd" } },
                go = { { "goimports-reviser", "goimports" }, { "golines", "gofumpt" } },
                csharp = { "csharpier" },
                python = { "black", "isort" },
                proto = { "buf" },
                markdown = { { "prettier", "prettierd" } },
                html = { { "prettier", "prettierd" } },
                css = { { "prettier", "prettierd" } },
                scss = { { "prettier", "prettierd" } },
                less = { { "prettier", "prettierd" } },
                vue = { { "prettier", "prettierd" } },
                json = { { "prettier", "prettierd" } },
                jsonc = { { "prettier", "prettierd" } },
                yaml = { { "prettier", "prettierd" } },
                graphql = { { "prettier", "prettierd" } },
                handlebars = { { "prettier", "prettierd" } },
            },
            formatters = {
                ["goimports-reviser"] = {
                    meta = {
                        url = "https://github.com/incu6us/goimports-reviser",
                        description = "Tool for Golang to sort goimports by 3-4 groups.",
                    },
                    command = "goimports-reviser",
                    args = { "-rm-unused", "-set-alias", "$FILENAME" },
                    stdin = false,
                    cwd = function()
                        return project.get_project_root_dir()
                    end
                },
                golines = utils.tbl_merge(require "conform.formatters.golines", {
                    args = { '-m', '180', '--no-reformat-tags', '--base-formatter', 'gofumpt' },
                })
            }
        }
    end,
    config = function(_, opts)
        local conform = require "conform"
        conform.setup(opts)

        local utils = require "utils"

        utils.auto_command(
            "BufWritePre",
             function(evt)
                local format = require "utils.format"

                if format.enabled() and format.enabled_for_buffer(evt.buf) then
                    format.apply(evt.buf)
                end
            end,
            "*"
        )
    end
}
