local icons = require 'ui.icons'

return {
    {
        'neovim/nvim-lspconfig',
        cond = feature_level(2),
        event = 'User NormalFile',
        dependencies = {
            'williamboman/mason-lspconfig.nvim',
            {
                'lvimuser/lsp-inlayhints.nvim',
                opts = {},
            },
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
                    source = 'always',
                    header = '',
                    prefix = '',
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
                bashls = {
                    bashIde = {
                        globPattern = '*@(.sh|.inc|.bash|.command)',
                    },
                },
                omnisharp = {
                    handlers = {
                        ['textDocument/definition'] = function(...)
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
                        -- add schemastore schemas
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
                        -- add schemastore schemas
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
                            completion = {
                                callSnippet = 'Replace',
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

            local utils = require 'core.utils'
            local lsp = require 'project.lsp'
            local keymaps = require 'project.keymaps'

            -- keymaps
            lsp.on_attach(keymaps.attach)

            -- diagnostics
            local signs = {
                { name = 'DiagnosticSignError', text = icons.Diagnostics.LSP.Error .. ' ', texthl = 'DiagnosticSignError' },
                { name = 'DiagnosticSignWarn', text = icons.Diagnostics.LSP.Warn .. ' ', texthl = 'DiagnosticSignWarn' },
                { name = 'DiagnosticSignHint', text = icons.Diagnostics.LSP.Hint .. ' ', texthl = 'DiagnosticSignHint' },
                { name = 'DiagnosticSignInfo', text = icons.Diagnostics.LSP.Info .. ' ', texthl = 'DiagnosticSignInfo' },
            }

            for _, sign in ipairs(signs) do
                vim.fn.sign_define(sign.name, sign)
            end

            if type(opts.diagnostics.virtual_text) == 'table' and opts.diagnostics.virtual_text.prefix == 'icons' then
                opts.diagnostics.virtual_text.prefix = vim.fn.has 'nvim-0.10.0' == 0 and icons.Diagnostics.Prefix
                    or function(diagnostic)
                        for d, icon in pairs(icons.Diagnostics) do
                            if diagnostic.severity == vim.diagnostic.severity[d:upper()] then
                                return icon
                            end
                        end
                    end
            end

            vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

            -- setup register capability
            local register_capability_name = 'client/registerCapability'
            local register_capability_handler = vim.lsp.handlers[register_capability_name]
            vim.lsp.handlers[register_capability_name] = function(err, res, ctx)
                local ret = register_capability_handler(err, res, ctx)

                ---@type LspClient
                local client = vim.lsp.get_client_by_id(ctx.client_id)

                if client.supports_method ~= nil then
                    keymaps.attach(client, vim.api.nvim_get_current_buf())
                end

                return ret
            end

            -- setup progress
            local progress_capability_name = '$/progress'
            local progress_capability_handler = vim.lsp.handlers[progress_capability_name]
            vim.lsp.handlers[progress_capability_name] = function(_, msg, info)
                utils.trigger_user_event('LspProgress', utils.tbl_merge(msg, { client_id = info.client_id }))
                progress_capability_handler(_, msg, info)
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
                        ['textDocument/rename'] = require 'project.rename',
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
        cond = feature_level(2),
        version = false, -- last release is way too old
    },
    {
        'pmizio/typescript-tools.nvim',
        cond = feature_level(2),
        ft = { 'typescript', 'typescript.jsx', 'typescriptreact', 'javascript', 'javascript.jsx', 'javascriptreact' },
        dependencies = {
            'nvim-lua/plenary.nvim',
            'neovim/nvim-lspconfig',
        },
        opts = {
            handlers = {
                ['textDocument/rename'] = require 'project.rename',
            },
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
                expose_as_code_action = { 'organize_imports', 'add_missing_imports' },
            },
        },
    },
    {
        'Wansmer/symbol-usage.nvim',
        cond = feature_level(3),
        event = 'BufReadPre', -- need run before LspAttach if you use nvim 0.9. On 0.10 use 'LspAttach'
        opts = {
            kinds = {
                vim.lsp.protocol.SymbolKind.Function,
                vim.lsp.protocol.SymbolKind.Method,
                vim.lsp.protocol.SymbolKind.Property,
                vim.lsp.protocol.SymbolKind.Interface,
                vim.lsp.protocol.SymbolKind.Class,
                vim.lsp.protocol.SymbolKind.Struct,
                vim.lsp.protocol.SymbolKind.Event,
                vim.lsp.protocol.SymbolKind.Constructor,
                vim.lsp.protocol.SymbolKind.Constant,
            },
            request_pending_text = icons.TUI.Ellipsis,
            vt_position = 'end_of_line',
            references = {
                enabled = true,
                include_declaration = false,
            },
            disable = { lsp = { 'lua_ls' } },
        },
    },
}
