local icons = require "utils.icons"

return {
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "williamboman/mason-lspconfig.nvim",
            {
                "lvimuser/lsp-inlayhints.nvim",
                opts = {},
            },
            {
                "Hoffs/omnisharp-extended-lsp.nvim"
            },
        },
        opts = {
            diagnostics = {
                underline = true,
                update_in_insert = true,
                virtual_text = {
                    spacing = 4,
                    source = "if_many",
                    prefix = icons.Diagnostics.Prefix,
                },
                severity_sort = true,
                float = {
                    focused = false,
                    style = "minimal",
                    border = "rounded",
                    source = "always",
                    header = "",
                    prefix = "",
                },
            },
            capabilities = {
                textDocument = {
                    foldingRange = {
                        dynamicRegistration = false,
                        lineFoldingOnly = true,
                    },
                    completion = {
                        completionItem = {
                            documentationFormat = { "markdown", "plaintext" },
                            snippetSupport = true,
                            preselectSupport = true,
                            insertReplaceSupport = true,
                            labelDetailsSupport = true,
                            deprecatedSupport = true,
                            commitCharactersSupport = true,
                            tagSupport = {
                                valueSet = { 1 }
                            },
                            resolveSupport = {
                                properties = {
                                    "documentation",
                                    "detail",
                                    "additionalTextEdits",
                                },
                            },
                        },
                    },
                },
            },
            servers = {
                bashls = {
                    bashIde = {
                        globPattern = "*@(.sh|.inc|.bash|.command)"
                    },
                },
                omnisharp = {
                    handlers = {
                        ["textDocument/definition"] = function(...)
                            return require("omnisharp_extended").handler(...)
                        end,
                    },
                    enable_roslyn_analyzers = true,
                    organize_imports_on_format = true,
                    enable_import_completion = true,
                },
                dockerls = {},
                taplo = {},
                yamlls = {
                    on_new_config = function(new_config)
                        -- add schemastore schemas
                        new_config.settings.yaml.schemas = new_config.settings.yaml.schemas or {}
                        vim.list_extend(new_config.settings.yaml.schemas, require("schemastore").yaml.schemas())
                    end,

                    settings = {
                        yaml = {},
                    }
                },
                docker_compose_language_service = {},
                html = {},
                cssls = {},
                emmet_ls = {},
                marksman = {},
                prismals = {},
                bufls = {},
                pyright = {},
                ruff_lsp = {},
                jsonls = {
                    on_new_config = function(new_config)
                        -- add schemastore schemas
                        new_config.settings.json.schemas = new_config.settings.json.schemas or {}
                        vim.list_extend(new_config.settings.json.schemas, require("schemastore").json.schemas())
                    end,

                    settings = {
                        json = {
                            format = {
                                enable = true,
                            },
                            validate = { enable = true },
                        },
                    },
                },
                lua_ls = {
                    settings = {
                        Lua = {
                            workspace = {
                                checkThirdParty = false,
                            },
                            completion = {
                                callSnippet = "Replace",
                            },
                        },
                    },
                },
                gopls = {
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
                                fieldalignment = false, -- too may complaints
                                nilness = true,
                                unusedparams = true,
                                unusedwrite = true,
                                useany = true,
                            },
                            usePlaceholders = true,
                            completeUnimported = true,
                            staticcheck = false,
                            directoryFilters = { "-.git", "-.vscode", "-.idea", "-.vscode-test", "-node_modules" },
                            semanticTokens = true,
                        },
                    },
                },
            },
            setup = {
                gopls = function(_, opts)
                    local lsp = require "utils.lsp"

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
        config = function(_, opts)
            -- set the border for the ui
            require('lspconfig.ui.windows').default_options.border = 'single'

            local utils = require "utils"
            local lsp = require "utils.lsp"
            local keymaps = require "utils.lsp.keymaps"

            -- keymaps
            lsp.on_attach(keymaps.attach)

            -- diagnostics
            local signs = {
                { name = "DiagnosticSignError", text = icons.Diagnostics.LSP.Error .. " ", texthl = "DiagnosticSignError" },
                { name = "DiagnosticSignWarn", text = icons.Diagnostics.LSP.Warn .. " ", texthl = "DiagnosticSignWarn" },
                { name = "DiagnosticSignHint", text = icons.Diagnostics.LSP.Hint .. " ", texthl = "DiagnosticSignHint" },
                { name = "DiagnosticSignInfo", text = icons.Diagnostics.LSP.Info .. " ", texthl = "DiagnosticSignInfo" },
            }

            for _, sign in ipairs(signs) do
                vim.fn.sign_define(sign.name, sign)
            end

            if type(opts.diagnostics.virtual_text) == "table" and opts.diagnostics.virtual_text.prefix == "icons" then
                opts.diagnostics.virtual_text.prefix = vim.fn.has("nvim-0.10.0") == 0 and icons.Diagnostics.Prefix
                or function(diagnostic)
                    local icons = icons.diagnostics
                    for d, icon in pairs(icons) do
                        if diagnostic.severity == vim.diagnostic.severity[d:upper()] then
                            return icon
                        end
                    end
                end
            end

            vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

            -- setup register capability
            local register_capability = vim.lsp.handlers["client/registerCapability"]
            vim.lsp.handlers["client/registerCapability"] = function(err, res, ctx)
                local ret = register_capability(err, res, ctx)
                local client = vim.lsp.get_client_by_id(ctx.client_id)

                if client.supports_method ~= nil then
                    keymaps.attach(client, vim.api.nvim_get_current_buf())
                end

                return ret
            end

            -- register cmp capabilities
            local cmp_nvim_lsp = require "cmp_nvim_lsp"
            local capabilities = utils.tbl_merge(
                vim.lsp.protocol.make_client_capabilities(),
                cmp_nvim_lsp.default_capabilities(),
                opts.capabilities
            )

            -- configure the servers
            local servers = opts.servers
            local function setup(server)
                local server_opts = utils.tbl_merge({ capabilities = vim.deepcopy(capabilities) }, servers[server] or {})

                if opts.setup[server] then
                    if opts.setup[server](server, server_opts) then
                        return
                    end
                elseif opts.setup["*"] then
                    if opts.setup["*"](server, server_opts) then
                        return
                    end
                end

                require("lspconfig")[server].setup(server_opts)
            end

            -- get all the servers that are available through mason-lspconfig
            local mlsp = require "mason-lspconfig"
            local all_mslp_servers = vim.tbl_keys(require("mason-lspconfig.mappings.server").lspconfig_to_package)

            local ensure_installed = {}
            for server, server_opts in pairs(servers) do
                if server_opts then
                    server_opts = server_opts == true and {} or server_opts
                    -- run manual setup if mason=false or if this is a server that cannot be installed with mason-lspconfig
                    if server_opts.mason == false or not vim.tbl_contains(all_mslp_servers, server) then
                        setup(server)
                    else
                        ensure_installed[#ensure_installed + 1] = server
                    end
                end
            end

            mlsp.setup({ ensure_installed = ensure_installed, handlers = { setup } })
        end
    },
    {
        "b0o/SchemaStore.nvim",
        version = false, -- last release is way too old
    },
    {
        "pmizio/typescript-tools.nvim",
        ft = { "typescript", "typescript.jsx", "typescriptreact", "javascript", "javascript.jsx", "javascriptreact" },
        dependencies = {
            "nvim-lua/plenary.nvim",
            "neovim/nvim-lspconfig",
        },
        opts = function()
            local lsp = require "utils.lsp"
            local keymaps = require "utils.lsp.keymaps"

            return {
                --on_attach = keymaps.attach,
                settings = {
                    tsserver_file_preferences = {
                        includeInlayParameterNameHints = 'all',
                        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                        includeInlayFunctionParameterTypeHints = true,
                        includeInlayVariableTypeHints = true,
                        includeInlayVariableTypeHintsWhenTypeMatchesName = false,
                        includeInlayPropertyDeclarationTypeHints = true,
                        includeInlayFunctionLikeReturnTypeHints = true,
                        includeInlayEnumMemberValueHints = true,
                    },
                    expose_as_code_action = { "organize_imports", "add_missing_imports" },
                    code_lens = "all"
                }
            }
        end,
    }
}
