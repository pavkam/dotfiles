
return {
    "stevearc/conform.nvim",
    dependencies = {
        {
            "williamboman/mason.nvim",
            opts = {
                ensure_installed = {
                    "shfmt",
                    "csharpier",
                    "stylua",
                    "buf",
                    "black", "isort",
                    "golines", "gofumpt", "goimports", "goimports-reviser",
                    "prettier", "prettierd"
                }
            }
        }
    },
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
                javascript = { { "prettierd", "prettier" } },
                javascriptreact = { { "prettierd", "prettier" } },
                typescript = { { "prettierd", "prettier" } },
                typescriptreact = { { "prettierd", "prettier" } },
                go = { { "goimports-reviser", "goimports" }, { "golines", "gofumpt" } },
                csharp = { "csharpier" },
                python = { "black", "isort" },
                proto = { "buf" },
                markdown = { { "prettierd", "prettier" } },
                html = { { "prettierd", "prettier" } },
                css = { { "prettierd", "prettier" } },
                scss = { { "prettierd", "prettier" } },
                less = { { "prettierd", "prettier" } },
                vue = { { "prettierd", "prettier" } },
                json = { { "prettierd", "prettier" } },
                jsonc = { { "prettierd", "prettier" } },
                yaml = { { "prettierd", "prettier" } },
                graphql = { { "prettierd", "prettier" } },
                handlebars = { { "prettierd", "prettier" } },
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
