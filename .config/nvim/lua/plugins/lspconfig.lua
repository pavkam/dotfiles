return {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        "folke/neodev.nvim",
        "folke/neoconf.nvim",
        "williamboman/mason-lspconfig.nvim",
        "williamboman/mason.nvim",
        "hrsh7th/cmp-nvim-lsp",
    },
    opts = {
        diagnostics = {
            underline = true,
            update_in_insert = false,
            virtual_text = {
                spacing = 4,
                source = "if_many",
                prefix = "●",
            },
            severity_sort = true,
        },
        inlay_hints = {
            enabled = false,
        },
        servers = {
            bashls = {
                bashIde = {
                    globPattern = "*@(.sh|.inc|.bash|.command)"
                },
            },
            csharp_ls = {},
            dockerls = {},
            taplo = {},
            yamlls = {},
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
                -- lazy-load schemastore when needed
                on_new_config = function(new_config)
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
            tsserver = {
                settings = {
                    typescript = {
                        inlayHints = {
                            includeInlayParameterNameHints = 'all',
                            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                            includeInlayFunctionParameterTypeHints = true,
                            includeInlayVariableTypeHints = true,
                            includeInlayVariableTypeHintsWhenTypeMatchesName = false,
                            includeInlayPropertyDeclarationTypeHints = true,
                            includeInlayFunctionLikeReturnTypeHints = true,
                            includeInlayEnumMemberValueHints = true,
                        }
                    },
                    javascript = {
                        inlayHints = {
                            includeInlayParameterNameHints = 'all',
                            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                            includeInlayFunctionParameterTypeHints = true,
                            includeInlayVariableTypeHints = true,
                            includeInlayVariableTypeHintsWhenTypeMatchesName = false,
                            includeInlayPropertyDeclarationTypeHints = true,
                            includeInlayFunctionLikeReturnTypeHints = true,
                            includeInlayEnumMemberValueHints = true,
                        },
                    },
                },
            },
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
        local lsp = require "utils.lsp"
        local icons = require "utils.icons"
        local format = require "utils.format"
        local lspm = require "utils.lsp-m"

        format.setup(opts)

        -- neoconf
        local plugin = require("lazy.core.config").spec.plugins["neoconf.nvim"]
        require("neoconf").setup(require("lazy.core.plugin").values(plugin, "opts", false))

        -- kaymaps
        lsp.on_attach(function(client, buffer)
            lspm.on_attach(client, buffer)
        end)

        local register_capability = vim.lsp.handlers["client/registerCapability"]

        vim.lsp.handlers["client/registerCapability"] = function(err, res, ctx)
            local ret = register_capability(err, res, ctx)

            lspm.on_attach(
                vim.lsp.get_client_by_id(ctx.client_id),
                vim.api.nvim_get_current_buf()
            )

            return ret
        end

        -- diagnostics
        for name, icon in pairs(icons.diagnostics) do
            name = "DiagnosticSign" .. name
            vim.fn.sign_define(name, { text = icon, texthl = name, numhl = "" })
        end

        if type(opts.diagnostics.virtual_text) == "table" and opts.diagnostics.virtual_text.prefix == "icons" then
            opts.diagnostics.virtual_text.prefix = vim.fn.has("nvim-0.10.0") == 0 and "●"
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

        -- inlay hints
        local inlay_hint = vim.lsp.buf.inlay_hint or vim.lsp.inlay_hint

        if opts.inlay_hints.enabled and inlay_hint then
            lsp.on_attach(function(client, buffer)
                if client.supports_method("textDocument/inlayHint") then
                    inlay_hint(buffer, true)
                end
            end)
        end

        -- register cmp capabilities
        local servers = opts.servers
        local cmp_nvim_lsp = require "cmp_nvim_lsp"
        local capabilities = vim.tbl_deep_extend(
            "force",
            {},
            vim.lsp.protocol.make_client_capabilities(),
            cmp_nvim_lsp.default_capabilities(),
            opts.capabilities or {}
        )

        -- configure the servers
        local function setup(server)
            local server_opts = vim.tbl_deep_extend("force", {
                capabilities = vim.deepcopy(capabilities),
            }, servers[server] or {})

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
}
