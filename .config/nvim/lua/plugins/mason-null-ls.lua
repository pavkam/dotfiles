return {
    "jay-babu/mason-null-ls.nvim",
    event = "LspAttach",
    dependencies = {
        "williamboman/mason.nvim",
        "nvimtools/none-ls.nvim",
    },
    opts = function(_, opts)
        local project = require "utils.project"
        local go_project = require "utils.p.go"

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

        null_ls = require("null-ls")

        local project_has_eslint_installed = function()
            return (
                project.node_package_json_has_dependency(nil, 'eslint')
                and project.node_project_has_eslint_config()
            )
        end

        null_ls.register(null_ls.builtins.diagnostics.eslint.with {
            condition = project_has_eslint_installed
        })
        null_ls.register(null_ls.builtins.code_actions.eslint.with {
            condition = project_has_eslint_installed
        })

        opts.handlers = {
            golines = function ()
                null_ls.register(null_ls.builtins.formatting.golines.with {
                    args = { '-m', '180', '--no-reformat-tags', '--base-formatter', 'gofumpt' }
                })
            end,
            staticcheck = function()
                null_ls.register(null_ls.builtins.diagnostics.staticcheck.with {
                    condition = function()
                        return not go_project.has_golangci_config()
                    end
                })
            end,
            golangci_lint = function()
                null_ls.register(null_ls.builtins.diagnostics.golangci_lint.with {
                    condition = function()
                        return go_project.has_golangci_config()
                    end
                })
            end,
            goimports = function() end,
            goimports_reviser = function()
                null_ls.register(null_ls.builtins.formatting.goimports_reviser)
            end,
            eslint_d = function()
                local condition = function()
                    return (
                        project.node_project_has_eslint_config()
                        and not project.node_package_json_has_dependency(nil, 'eslint')
                    )
                end

                null_ls.register(null_ls.builtins.diagnostics.eslint_d.with {
                    condition = condition
                })
                null_ls.register(null_ls.builtins.code_actions.eslint_d.with {
                    condition = condition
                })
            end,
            prettierd = function()
                null_ls.register(null_ls.builtins.formatting.prettierd.with {
                    condition = function()
                        return not project.node_package_json_has_dependency(nil, 'prettier')
                    end
                })
            end,
            prettier = function()
                null_ls.register(null_ls.builtins.formatting.prettier.with {
                    condition = function()
                        return project.node_package_json_has_dependency(nil, 'prettier')
                    end
                })
            end,
        }
    end
}
