local icons = require 'ui.icons'

return {
    {
        'neovim/nvim-lspconfig',
        event = 'User NormalFile',
        dependencies = {
            'williamboman/mason-lspconfig.nvim',
            'Hoffs/omnisharp-extended-lsp.nvim',
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
            handlers = {
                [vim.lsp.protocol.Methods.textDocument_rename] = require 'project.rename',
            },
            servers = {
                typos_lsp = {
                    init_options = {
                        diagnosticSeverity = 'Hint',
                    },
                },
                bashls = {
                    bashIde = {
                        globPattern = '*@(.sh|.inc|.bash|.command)',
                    },
                },
                omnisharp = {
                    handlers = {
                        [vim.lsp.protocol.Methods.textDocument_definition] = function(...)
                            return require('omnisharp_extended').handler(...)
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
                        -- add schema-store schemas
                        new_config.settings.yaml.schemas = new_config.settings.yaml.schemas or {}
                        vim.list_extend(new_config.settings.yaml.schemas, require('schemastore').yaml.schemas())
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
                bufls = {},
                pyright = {},
                ruff_lsp = {},
                jsonls = {
                    on_new_config = function(new_config)
                        -- add schema-store schemas
                        new_config.settings.json.schemas = new_config.settings.json.schemas or {}
                        vim.list_extend(new_config.settings.json.schemas, require('schemastore').json.schemas())
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
                            codeLens = {
                                enable = true,
                            },
                            completion = {
                                callSnippet = 'Replace',
                            },
                            doc = {
                                privateName = { '^_' },
                            },
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
                -- tsserver = {
                --     single_file_support = false,
                --     settings = {
                --         typescript = {
                --             inlayHints = {
                --                 includeInlayParameterNameHints = 'literal',
                --                 includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                --                 includeInlayFunctionParameterTypeHints = true,
                --                 includeInlayVariableTypeHints = false,
                --                 includeInlayPropertyDeclarationTypeHints = true,
                --                 includeInlayFunctionLikeReturnTypeHints = true,
                --                 includeInlayEnumMemberValueHints = true,
                --             },
                --         },
                --         javascript = {
                --             inlayHints = {
                --                 includeInlayParameterNameHints = 'all',
                --                 includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                --                 includeInlayFunctionParameterTypeHints = true,
                --                 includeInlayVariableTypeHints = true,
                --                 includeInlayPropertyDeclarationTypeHints = true,
                --                 includeInlayFunctionLikeReturnTypeHints = true,
                --                 includeInlayEnumMemberValueHints = true,
                --             },
                --         },
                --         completions = {
                --             completeFunctionCalls = true,
                --         },
                --     },
                -- },
                vtsls = {
                    single_file_support = false,
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
                                fieldalignment = false, -- too noisy
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
                    ---@param client vim.lsp.Client
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
        config = function(_, opts)
            -- set the border for the UI
            require('lspconfig.ui.windows').default_options.border = vim.g.border_style

            local utils = require 'core.utils'
            local buffers = require 'core.buffers'
            local events = require 'core.events'
            local lsp = require 'project.lsp'
            local features = require 'project.features'

            -- fix the root_dir for ts-server
            opts.servers.vtsls.root_dir = require('lspconfig.util').root_pattern(
                'lerna.json',
                'tsconfig.json',
                'jsconfig.json',
                'package.json',
                '.git'
            )

            -- on attach work
            lsp.on_attach(function(client, buffer)
                if buffers.is_special_buffer(buffer) then
                    vim.schedule(function()
                        vim.lsp.buf_detach_client(buffer, client.id)
                    end)
                else
                    features.attach(client, buffer)
                end
            end)

            vim.diagnostic.config(opts.diagnostics)

            -- setup register capability
            local register_capability_handler = vim.lsp.handlers[vim.lsp.protocol.Methods.client_registerCapability]
            vim.lsp.handlers[vim.lsp.protocol.Methods.client_registerCapability] = function(err, res, ctx)
                local ret = register_capability_handler(err, res, ctx)

                local client = assert(vim.lsp.get_client_by_id(ctx.client_id))

                if client.supports_method ~= nil then
                    features.attach(client, vim.api.nvim_get_current_buf())
                end

                return ret
            end

            -- setup progress
            local progress_capability_handler = vim.lsp.handlers[vim.lsp.protocol.Methods.dollar_progress]
            vim.lsp.handlers[vim.lsp.protocol.Methods.dollar_progress] = function(_, msg, info)
                events.trigger_user_event('LspProgress', vim.tbl_merge(msg, { client_id = info.client_id }))
                progress_capability_handler(_, msg, info)
            end

            -- register nvim-cmp capabilities
            local cmp_nvim_lsp = require 'cmp_nvim_lsp'
            local capabilities = vim.tbl_merge(
                vim.lsp.protocol.make_client_capabilities(),
                cmp_nvim_lsp.default_capabilities(),
                opts.capabilities
            )

            -- configure the servers
            local servers = opts.servers
            local function setup(server)
                local server_opts = vim.tbl_merge({
                    capabilities = vim.deepcopy(capabilities),
                    handlers = opts.handlers,
                }, servers[server] or {})

                require('lspconfig')[server].setup(server_opts)
            end

            -- get all the servers that are available through mason-LSP-config
            local through_mason = vim.has_plugin 'mason.nvim'
            local mlsp = through_mason and require 'mason-lspconfig' or nil
            local all_mslp_servers = through_mason
                    and vim.tbl_keys(require('mason-lspconfig.mappings.server').lspconfig_to_package)
                or {}

            local ensure_installed = {}
            for server, server_opts in pairs(servers) do
                if server_opts then
                    server_opts = server_opts == true and {} or server_opts
                    -- run manual setup if mason=false or if this is a server that cannot be
                    -- installed with mason-LSP-config
                    if server_opts.mason == false or not vim.tbl_contains(all_mslp_servers, server) then
                        setup(server)
                    else
                        ensure_installed[#ensure_installed + 1] = server
                    end
                end
            end

            if mlsp then
                mlsp.setup { ensure_installed = ensure_installed, handlers = { setup } }
            end

            -- re-trigger FileType auto-commands to force LSP to start
            vim.api.nvim_exec_autocmds('FileType', {})
        end,
    },
    {
        'b0o/SchemaStore.nvim',
        version = false, -- last release is way too old
    },
}
