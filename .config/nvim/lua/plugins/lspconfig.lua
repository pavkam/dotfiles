local icons = require 'icons'

---@module "lspconfig"

return {
    {
        'neovim/nvim-lspconfig',
        cond = not ide.process.is_headless,
        event = 'User NormalFile',
        dependencies = {
            'williamboman/mason-lspconfig.nvim', -- TODO: disable autoloading of all servers that mason installed
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
            handlers = {
                [vim.lsp.protocol.Methods.textDocument_rename] = require 'rename',
            },
            ---@type table<string, lspconfig.Config>
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
                buf_ls = {
                    mason_package = 'bufls',
                },
                pyright = {},
                ruff = {},
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

            local events = require 'events'
            local lsp = require 'lsp'
            local features = require 'features'

            -- fix the root_dir for ts-server
            opts.servers.vtsls.root_dir = require('lspconfig.util').root_pattern(
                'lerna.json',
                'tsconfig.json',
                'jsconfig.json',
                'package.json',
                '.git'
            )

            -- TODO: move this to a new file
            -- on attach work
            lsp.on_attach(function(client, buffer)
                if vim.buf.is_special(buffer) then
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
                events.trigger_user_event('LspProgress', table.merge(msg, { client_id = info.client_id }))
                progress_capability_handler(_, msg, info)
            end

            -- register nvim-cmp capabilities
            local cmp_nvim_lsp = require 'cmp_nvim_lsp'
            local capabilities = table.merge(
                vim.lsp.protocol.make_client_capabilities(),
                cmp_nvim_lsp.default_capabilities(),
                opts.capabilities
            )

            -- configure the servers
            local function setup(server)
                local server_opts = opts.servers[server]

                server_opts = table.merge({
                    capabilities = vim.deepcopy(capabilities),
                    handlers = opts.handlers,
                }, server_opts or {})

                local lsp_server = require('lspconfig')[server]
                if not lsp_server or not lsp_server.setup then
                    ide.tui.error(
                        string.format('Language server `%s` does not appear to be present in `lspconfig`.' .. server)
                    )
                    return
                end

                lsp_server.setup(server_opts)
            end

            -- get all the servers that are available through mason-LSP-config
            local using_mason = ide.plugins.has 'mason.nvim'
            local mason_packages = using_mason and require('mason-lspconfig.mappings.server').lspconfig_to_package or {}

            local ensure_installed = {}
            for server, server_opts in pairs(opts.servers) do
                server_opts = server_opts == true and {} or server_opts
                local package_name = type(server_opts) == 'table'
                        and type(server_opts.mason_package) == 'string'
                        and server_opts.mason_package
                    or nil

                local mason_package_for_server = mason_packages[server]
                local mason_package_for_alias = mason_packages[package_name]

                if mason_package_for_server == mason_package_for_alias == nil then
                    ide.tui.error(string.format('Server `%s` could not be located in mason registry.', server))
                elseif mason_package_for_server == mason_package_for_alias then
                    ide.tui.warn(
                        string.format(
                            'Server `%s` has the same mason package as its alias `%s`. Consider removing the alias.',
                            server,
                            server_opts.mason_package
                        )
                    )
                else
                    if not mason_package_for_server and not mason_package_for_alias then
                        setup(package_name or server)
                    else
                        table.insert(ensure_installed, package_name or server)
                    end
                end
            end

            local mason_lsp_config = ide.plugins.has 'mason-lspconfig.nvim'
                    and using_mason
                    and require 'mason-lspconfig'
                or nil

            if mason_lsp_config then
                local mason_opts = assert(ide.plugins.config 'mason-lspconfig.nvim')

                mason_lsp_config.setup {
                    ensure_installed = vim.tbl_deep_extend(
                        'force',
                        ensure_installed,
                        mason_opts.ensure_installed or {}
                    ),
                    handlers = { setup },
                }
            end

            -- re-trigger FileType auto-commands to force LSP to start
            vim.schedule(function()
                vim.api.nvim_exec_autocmds('FileType', { data = { buf = vim.api.nvim_get_current_buf() } })
            end)
        end,
    },
    {
        'b0o/SchemaStore.nvim',
        dependencies = {
            'neovim/nvim-lspconfig',
        },
        version = false, -- last release is way too old
    },
}
