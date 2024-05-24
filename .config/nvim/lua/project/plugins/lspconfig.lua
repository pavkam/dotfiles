local icons = require 'ui.icons'
local settings = require 'core.settings'

return {
    {
        'neovim/nvim-lspconfig',
        event = 'User NormalFile',
        dependencies = {
            'williamboman/mason-lspconfig.nvim',
            {
                'Hoffs/omnisharp-extended-lsp.nvim',
            },
            {
                'folke/neodev.nvim',
                opts = {
                    library = {
                        enabled = true,
                        runtime = true,
                        types = true,
                        plugins = true,
                    },
                },
            },
        },
        opts = {
            ---@type vim.diagnostic.Opts
            diagnostics = {
                underline = true,
                update_in_insert = true,
                virtual_text = {
                    spacing = 4,
                    source = 'if_many',
                    prefix = icons.Diagnostics.Prefix,
                },
                severity_sort = true,
                float = {
                    focused = false,
                    style = 'minimal',
                    border = 'rounded',
                    source = true,
                    header = '',
                    prefix = icons.Diagnostics.Prefix .. ' ',
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
                tsserver = {
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
                },
            },
            setup = {
                gopls = function()
                    local lsp = require 'project.lsp'

                    -- HACK: workaround for gopls not supporting semanticTokensProvider
                    -- https://github.com/golang/go/issues/54531#issuecomment-1464982242
                    lsp.on_attach(function(client, _)
                        if client.name == 'gopls' then
                            if not client.server_capabilities.semanticTokensProvider then
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
                            end
                        end
                    end)
                end,
            },
        },
        config = function(_, opts)
            -- set the border for the ui
            require('lspconfig.ui.windows').default_options.border = 'single'

            local utils = require 'core.utils'
            local lsp = require 'project.lsp'
            local keymaps = require 'project.keymaps'

            -- keymaps
            lsp.on_attach(keymaps.attach)

            vim.diagnostic.config(opts.diagnostics)

            -- setup register capability
            local register_capability_handler = vim.lsp.handlers[vim.lsp.protocol.Methods.client_registerCapability]
            vim.lsp.handlers[vim.lsp.protocol.Methods.client_registerCapability] = function(err, res, ctx)
                local ret = register_capability_handler(err, res, ctx)

                local client = assert(vim.lsp.get_client_by_id(ctx.client_id))

                if client.supports_method ~= nil then
                    keymaps.attach(client, vim.api.nvim_get_current_buf())
                end

                return ret
            end

            -- setup progress
            local progress_capability_handler = vim.lsp.handlers[vim.lsp.protocol.Methods.dollar_progress]
            vim.lsp.handlers[vim.lsp.protocol.Methods.dollar_progress] = function(_, msg, info)
                utils.trigger_user_event('LspProgress', utils.tbl_merge(msg, { client_id = info.client_id }))
                progress_capability_handler(_, msg, info)
            end

            -- setup progress
            local diagnostics_capability_handler = vim.lsp.handlers[vim.lsp.protocol.Methods.textDocument_publishDiagnostics]
            vim.lsp.handlers[vim.lsp.protocol.Methods.textDocument_publishDiagnostics] = function(_, result, ctx, config)
                lsp.notice_diagnostics(result, ctx.client_id)
                diagnostics_capability_handler(_, result, ctx, config)
            end

            -- register cmp capabilities
            local cmp_nvim_lsp = require 'cmp_nvim_lsp'
            local capabilities = utils.tbl_merge(vim.lsp.protocol.make_client_capabilities(), cmp_nvim_lsp.default_capabilities(), opts.capabilities)

            -- configure the servers
            local servers = opts.servers
            local function setup(server)
                local server_opts = utils.tbl_merge({
                    capabilities = vim.deepcopy(capabilities),
                    handlers = {
                        [vim.lsp.protocol.Methods.textDocument_rename] = require 'project.rename',
                    },
                }, servers[server] or {})

                if opts.setup[server] then
                    if opts.setup[server](server, server_opts) then
                        return
                    end
                elseif opts.setup['*'] then
                    if opts.setup['*'](server, server_opts) then
                        return
                    end
                end

                require('lspconfig')[server].setup(server_opts)
            end

            -- get all the servers that are available through mason-lspconfig
            local mlsp = require 'mason-lspconfig'
            local all_mslp_servers = vim.tbl_keys(require('mason-lspconfig.mappings.server').lspconfig_to_package)

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

            mlsp.setup { ensure_installed = ensure_installed, handlers = { setup } }

            -- re-trigger FileType autocmds to force LSP to start
            vim.api.nvim_exec_autocmds('FileType', {})
        end,
    },
    {
        'b0o/SchemaStore.nvim',
        version = false, -- last release is way too old
    },
}
