local utils = require "utils"
local lsp = require "utils.lsp"

return {
    {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
            utils.list_insert_unique(opts.ensure_installed, {
                "go",
                "gomod",
                "gowork",
                "gosum",
            })
        end,
    },
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                gopls = {
                    keys = {
                        { "<leader>td", "<cmd>lua require('dap-go').debug_test()<CR>", desc = "Debug Test (Go)" },
                    },
                    settings = {
                        gopls = {
                            gofumpt = true,
                            codelenses = {
                                gc_details = false,
                                generate = true,
                                regenerate_cgo = true,
                                run_govulncheck = true,
                                test = true,
                                tidy = true,
                                upgrade_dependency = true,
                                vendor = true,
                            },
                            hints = {
                                assignVariableTypes = true,
                                compositeLiteralFields = true,
                                compositeLiteralTypes = true,
                                constantValues = true,
                                functionTypeParameters = true,
                                parameterNames = true,
                                rangeVariableTypes = true,
                            },
                            analyses = {
                                fieldalignment = true,
                                nilness = true,
                                unusedparams = true,
                                unusedwrite = true,
                                useany = true,
                            },
                            usePlaceholders = true,
                            completeUnimported = true,
                            staticcheck = true,
                            directoryFilters = { "-.git", "-.vscode", "-.idea", "-.vscode-test", "-node_modules" },
                            semanticTokens = true,
                        },
                    },
                },
            },
            setup = {
                gopls = function(_, opts)
                    -- TODO: workaround for gopls not supporting semanticTokensProvider
                    -- https://github.com/golang/go/issues/54531#issuecomment-1464982242
                    lsp.on_attach(function(client, _)
                        if client.name == "gopls" then
                            if not client.server_capabilities.semanticTokensProvider then
                                local semantic = client.config.capabilities.textDocument.semanticTokens
                                client.server_capabilities.semanticTokensProvider = {
                                full = true,
                                legend = {
                                    tokenTypes = semantic.tokenTypes,
                                    tokenModifiers = semantic.tokenModifiers,
                                },
                                range = true,
                                }
                            end
                        end
                    end)
                end,
            },
        },
    },
    {
        "nvimtools/none-ls.nvim",
        dependancies = {
            {
                "jay-babu/mason-null-ls.nvim",
                opts = function(_, opts)
                opts.ensure_installed =
                    utils.list_insert_unique(opts.ensure_installed, { "gomodifytags", "gofumpt", "iferr", "impl", "goimports" })
                end,
            }
        }
    },
    {
        "mfussenegger/nvim-dap",
        dependancies = {
            {
                "leoluz/nvim-dap-go",
                config = true,
            },
            {
                "jay-babu/mason-nvim-dap.nvim",
                opts = function(_, opts) opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "delve") end,
            },
        }
    },
    {
        "ray-x/go.nvim",
        dependencies = {
            "ray-x/guihua.lua",
            "neovim/nvim-lspconfig",
            "nvim-treesitter/nvim-treesitter",
        },
        opts = {},
        event = { "CmdlineEnter" },
        ft = { "go", "gomod" },
        build = ':lua require("go.install").update_all_sync()',
    },
    {
        "nvim-neotest/neotest",
        dependencies = {
            "nvim-neotest/neotest-go",
        },
        opts = {
            adapters = {
                ["neotest-go"] = {
                -- Here we can set options for neotest-go, e.g.
                -- args = { "-tags=integration" }
                },
            },
        },
    },
}
