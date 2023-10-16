return {
    "nvimtools/none-ls.nvim",
    -- TODO: disabling while testing conform and nvim-lint
    enabled = false,
    event = { "BufReadPre", "BufNewFile" },
    opts = function()
        local go_project = require "utils.project.go"
        local js_project = require "utils.project.js"

        local keymaps = require "utils.lsp.keymaps"
        local nls = require "null-ls"

        local has_eslint = function()
            return js_project.has_dependency(nil, 'eslint') and js_project.get_eslint_config_path() ~= nil
        end

        return {
            sources = {
                -- js
                -- nls.builtins.formatting.eslint_d.with {
                --     condition = has_eslint,
                -- },
                nls.builtins.diagnostics.eslint.with {
                    condition = has_eslint,
                },
                nls.builtins.code_actions.eslint.with {
                    condition = has_eslint,
                },
                nls.builtins.formatting.prettier,

                -- shell
                nls.builtins.code_actions.shellcheck,
                nls.builtins.diagnostics.shellcheck,
                nls.builtins.formatting.shfmt,

                -- csharp
                nls.builtins.formatting.csharpier,

                -- docker
                nls.builtins.diagnostics.hadolint,

                -- lua
                nls.builtins.formatting.stylua,
                nls.builtins.diagnostics.luacheck,

                -- protobuf
                nls.builtins.formatting.buf,
                nls.builtins.diagnostics.buf,

                -- python
                nls.builtins.formatting.black,
                nls.builtins.formatting.isort,

                -- go
                nls.builtins.code_actions.gomodifytags,
                nls.builtins.code_actions.impl,

                nls.builtins.diagnostics.staticcheck.with {
                    condition = function()
                        return not go_project.get_golangci_config()
                    end,
                },
                nls.builtins.diagnostics.golangci_lint.with {
                    condition = function()
                        return go_project.get_golangci_config() ~= nil
                    end,
                },

                nls.builtins.formatting.golines.with {
                    args = { '-m', '180', '--no-reformat-tags', '--base-formatter', 'gofumpt' }
                },

                nls.builtins.formatting.gofumpt,
                nls.builtins.formatting.goimports_reviser,
            },
            on_attach = keymaps.attach
        }
    end,
}
