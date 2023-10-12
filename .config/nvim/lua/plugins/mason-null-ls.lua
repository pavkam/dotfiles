return {
    "jay-babu/mason-null-ls.nvim",
    event = "LspAttach",
    dependencies = {
        "williamboman/mason.nvim",
        "nvimtools/none-ls.nvim",
    },
    opts = function(_, opts)
        local project = require "utils.project"
        local go_project = require "utils.project.go"
        local js_project = require "utils.project.js"

        opts.ensure_installed = {
            "shellcheck", "shfmt",
            "csharpier",
            "hadolint",
            "stylua", "luacheck",
            "buf",
            "black", "isort",
            "gomodifytags", "gofumpt", "iferr", "impl", "goimports",
            "golines", "golangci_lint", "staticcheck", "goimports_reviser",
        }

        opts.handlers = opts.handlers or {}

        null_ls = require("null-ls")

        -- utils
        local get_project_dir = function()
            return project.get_project_root_dir()
        end

        -- Javascript
        null_ls.register(null_ls.builtins.diagnostics.eslint.with {
            condition = function()
                return js_project.has_dependency(nil, 'eslint') and js_project.get_eslint_config_path() ~= nil
            end,
            cwd = get_project_dir
        })
        null_ls.register(null_ls.builtins.code_actions.eslint.with {
            condition = function()
                return js_project.has_dependency(nil, 'eslint') and js_project.get_eslint_config_path() ~= nil
            end,
            cwd = get_project_dir
        })
        null_ls.register(null_ls.builtins.formatting.prettier.with {
            condition = function()
                return js_project.has_dependency(nil, 'prettier')
            end,
            cwd = get_project_dir
        })

        -- GO
        opts.handlers.golines = function ()
            null_ls.register(null_ls.builtins.formatting.golines.with {
                args = { '-m', '180', '--no-reformat-tags', '--base-formatter', 'gofumpt' }
            })
        end
        opts.handlers.staticcheck = function()
            null_ls.register(null_ls.builtins.diagnostics.staticcheck.with {
                condition = function()
                    return not go_project.get_golangci_config()
                end,
                cwd = get_project_dir
            })
        end
        opts.handlers.golangci_lint = function()
            null_ls.register(null_ls.builtins.diagnostics.golangci_lint.with {
                condition = function()
                    return go_project.get_golangci_config()
                end,
                cwd = get_project_dir
            })
        end

        opts.handlers.goimports = function() end
    end
}
