local utils = require 'astronvim.utils'
return {
    'jay-babu/mason-null-ls.nvim',
    opts = function(_, opts)
        opts.ensure_installed =
            utils.list_insert_unique(opts.ensure_installed, { 'golines', 'golangci_lint', 'staticcheck', 'goimports_reviser', 'prettier', 'eslint' })

        null_ls = require("null-ls")

        null_ls.register(null_ls.builtins.diagnostics.eslint)
        null_ls.register(null_ls.builtins.code_actions.eslint)

        --
        goloangci_lint_config_present = function(utils)
            return utils.root_has_file ".golangci.yml"
                or utils.root_has_file ".golangci.yaml"
                or utils.root_has_file ".golangci.toml"
                or utils.root_has_file ".golangci.json"
        end

        opts.handlers = {
            golines = function ()
                null_ls.register(null_ls.builtins.formatting.golines.with {
                    args = { '-m', '180', '--no-reformat-tags', '--base-formatter', 'gofumpt' }
                })
            end,
            staticcheck = function()
                null_ls.register(null_ls.builtins.diagnostics.staticcheck.with {
                    condition = function(utils)
                        return not goloangci_lint_config_present(utils)
                    end
                })
            end,
            golangci_lint = function()
                null_ls.register(null_ls.builtins.diagnostics.golangci_lint.with {
                    condition = function(utils)
                        return goloangci_lint_config_present(utils)
                    end
                })
            end,
            goimports = function() end,
            goimports_reviser = function()
                null_ls.register(null_ls.builtins.formatting.goimports_reviser)
            end,
            eslint_d = function() end,
            -- eslint = function()
            --     null_ls.register(null_ls.builtins.diagnostics.eslint)
            --     null_ls.register(null_ls.builtins.code_actions.eslint)
            -- end,
            prettierd = function() end,
            prettier = function()
                null_ls.register(null_ls.builtins.formatting.prettier)
            end,
        }
    end
}
