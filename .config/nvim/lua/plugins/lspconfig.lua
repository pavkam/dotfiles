local icons = require 'icons'

return {
    {
        'neovim/nvim-lspconfig',
        cond = #vim.api.nvim_list_uis() > 0,
        event = { 'BufReadPost', 'BufNewFile' },
        dependencies = {
            'williamboman/mason-lspconfig.nvim',
        },
        opts = {
            ---@type vim.diagnostic.Opts
            diagnostics = {
                underline = true,
                update_in_insert = true,
                virtual_text = {
                    spacing = 4,
                    source = 'if_many',
                    prefix = icons.fit(icons.Diagnostics.Prefix, 2),
                },
                severity_sort = true,
                float = {
                    focused = false,
                    style = 'minimal',
                    border = vim.g.border_style,
                    source = true,
                    header = '',
                    prefix = icons.fit(icons.Diagnostics.Prefix, 2),
                },
                signs = {
                    text = {
                        [vim.diagnostic.severity.ERROR] = icons.Diagnostics.LSP.Error,
                        [vim.diagnostic.severity.WARN] = icons.Diagnostics.LSP.Warn,
                        [vim.diagnostic.severity.HINT] = icons.Diagnostics.LSP.Hint,
                        [vim.diagnostic.severity.INFO] = icons.Diagnostics.LSP.Info,
                    },
                    numhl = {
                        [vim.diagnostic.severity.ERROR] = 'DiagnosticSignError',
                        [vim.diagnostic.severity.WARN] = 'DiagnosticSignWarn',
                        [vim.diagnostic.severity.HINT] = 'DiagnosticSignHint',
                        [vim.diagnostic.severity.INFO] = 'DiagnosticSignInfo',
                    },
                },
            },
            capabilities = {
                workspace = {
                    fileOperations = {
                        didRename = true,
                        willRename = true,
                    },
                },
                textDocument = {
                    foldingRange = {
                        dynamicRegistration = false,
                        lineFoldingOnly = true,
                    },
                    completion = {
                        completionItem = {
                            documentationFormat = { 'markdown', 'plaintext' },
                            snippetSupport = true,
                            preselectSupport = true,
                            insertReplaceSupport = true,
                            labelDetailsSupport = true,
                            deprecatedSupport = true,
                            commitCharactersSupport = true,
                            tagSupport = {
                                valueSet = { 1 },
                            },
                            resolveSupport = {
                                properties = {
                                    'documentation',
                                    'detail',
                                    'additionalTextEdits',
                                },
                            },
                        },
                    },
                },
            },
            servers = {
                typos_lsp = {
                    init_options = {
                        diagnosticSeverity = 'Hint',
                    },
                },
                bashls = {
                    settings = {
                        bashIde = {
                            globPattern = '*@(.sh|.inc|.bash|.command)',
                        },
                    },
                },
                dockerls = {},
                taplo = {},
                yamlls = {
                    before_init = function(_, config)
                        config.settings.yaml = config.settings.yaml or {}
                        config.settings.yaml.schemas = config.settings.yaml.schemas or {}
                        vim.list_extend(config.settings.yaml.schemas, require('schemastore').yaml.schemas())
                    end,
                    settings = {
                        yaml = {},
                    },
                },
                docker_compose_language_service = {},
                html = {},
                cssls = {},
                emmet_ls = {},
                marksman = {},
                prismals = {},
                buf_ls = {},
                pyright = {},
                ruff = {},
                jsonls = {
                    before_init = function(_, config)
                        config.settings.json = config.settings.json or {}
                        config.settings.json.schemas = config.settings.json.schemas or {}
                        vim.list_extend(config.settings.json.schemas, require('schemastore').json.schemas())
                    end,
                    settings = {
                        json = {
                            format = { enable = true },
                            validate = { enable = true },
                        },
                    },
                },
                lua_ls = {
                    settings = {
                        Lua = {
                            workspace = { checkThirdParty = false },
                            codeLens = { enable = true },
                            completion = { callSnippet = 'Replace' },
                            doc = { privateName = { '^_' } },
                            hint = {
                                enable = true,
                                setType = false,
                                paramType = true,
                                paramName = 'Disable',
                                semicolon = 'Disable',
                                arrayIndex = 'Disable',
                            },
                        },
                    },
                },
                vtsls = {
                    single_file_support = false,
                    root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
                    settings = {
                        typescript = {
                            inlayHints = {
                                includeInlayParameterNameHints = 'literal',
                                includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                                includeInlayFunctionParameterTypeHints = true,
                                includeInlayVariableTypeHints = false,
                                includeInlayPropertyDeclarationTypeHints = true,
                                includeInlayFunctionLikeReturnTypeHints = true,
                                includeInlayEnumMemberValueHints = true,
                            },
                        },
                        javascript = {
                            inlayHints = {
                                includeInlayParameterNameHints = 'all',
                                includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                                includeInlayFunctionParameterTypeHints = true,
                                includeInlayVariableTypeHints = true,
                                includeInlayPropertyDeclarationTypeHints = true,
                                includeInlayFunctionLikeReturnTypeHints = true,
                                includeInlayEnumMemberValueHints = true,
                            },
                        },
                        completions = {
                            completeFunctionCalls = true,
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
                                fieldalignment = false,
                                nilness = true,
                                unusedparams = true,
                                unusedwrite = true,
                                useany = true,
                            },
                            usePlaceholders = true,
                            completeUnimported = true,
                            staticcheck = false,
                            directoryFilters = { '-.git', '-.vscode', '-.idea', '-.vscode-test', '-node_modules' },
                            semanticTokens = true,
                        },
                    },
                    on_attach = function(client)
                        if client.server_capabilities.semanticTokensProvider then
                            return
                        end
                        local semantic = client.config.capabilities.textDocument.semanticTokens
                        if semantic then
                            client.server_capabilities.semanticTokensProvider = {
                                full = true,
                                legend = {
                                    tokenTypes = semantic.tokenTypes,
                                    tokenModifiers = semantic.tokenModifiers,
                                },
                                range = true,
                            }
                        end
                    end,
                },
            },
        },
        -- Uses the native vim.lsp.config() + vim.lsp.enable() API (nvim 0.12+).
        -- nvim-lspconfig is kept as a dependency because it provides default cmd/filetypes/root_markers
        -- for each server, which vim.lsp.config() reads automatically.
        config = function(_, opts)
            local Buffer = require 'ide.Buffer'

            -- Detach LSP from special buffers (file tree, panels, etc.)
            IDE.lsp:on_attach(function(client, buffer)
                if Buffer.is_special(buffer) then
                    vim.schedule(function()
                        if vim.api.nvim_buf_is_valid(buffer) then
                            pcall(vim.lsp.buf_detach_client, buffer, client.id)
                        end
                    end)
                end
            end)

            vim.diagnostic.config(opts.diagnostics)

            -- Completion is handled by ide/extensions/completion.lua

            -- Capabilities (no more cmp_nvim_lsp)
            local capabilities = table.merge(
                vim.lsp.protocol.make_client_capabilities(),
                opts.capabilities
            )

            -- global LSP defaults
            vim.lsp.config('*', {
                capabilities = vim.deepcopy(capabilities),
                root_markers = { '.git' },
            })

            -- configure each server via vim.lsp.config
            local server_names = {}
            for server, server_opts in pairs(opts.servers) do
                if server_opts and next(server_opts) then
                    vim.lsp.config(server, server_opts)
                end
                table.insert(server_names, server)
            end

            -- set up mason-lspconfig if available
            local using_mason = pcall(require, 'mason')
            if using_mason and pcall(require, 'mason-lspconfig') then
                local mason_map = require('mason-lspconfig.mappings').get_mason_map()
                local ensure_installed = {}
                for _, server in ipairs(server_names) do
                    if mason_map.lspconfig_to_package[server] then
                        table.insert(ensure_installed, server)
                    end
                end

                require('mason-lspconfig').setup {
                    ensure_installed = ensure_installed,
                    automatic_enable = false,
                }
            end

            -- enable all servers
            vim.lsp.enable(server_names)
        end,
    },
    {
        'b0o/SchemaStore.nvim',
        dependencies = {
            'neovim/nvim-lspconfig',
        },
        version = false,
    },
}
