local lsp = require "utils.lsp"
local icons = require "utils.icons"
local apply_lsp_keymaps = require "lsp-keymaps"
local format = require "utils.format"
local lspm = require "utils.lsp-m"

return {
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            { "folke/neoconf.nvim", cmd = "Neoconf", config = false, dependencies = { "nvim-lspconfig" } },
            { "folke/neodev.nvim", opts = {} },
            { "mason.nvim" },
            { "williamboman/mason-lspconfig.nvim" },
            { "hrsh7th/cmp-nvim-lsp" },
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
        },
        config = function(_, opts)
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
        end,
    },
    {
        "nvimtools/none-ls.nvim",
        dependancies = {
            "jay-babu/mason-null-ls.nvim",
        },
        event = { "BufReadPre", "BufNewFile" },
        dependencies = { "williamboman/mason.nvim" },
    },
    {
        "williamboman/mason.nvim",
        dependancies = {
            "jay-babu/mason-nvim-dap.nvim",
        },
        cmd = {
            "Mason",
            "MasonInstall",
            "MasonUninstall",
            "MasonUninstallAll",
            "MasonLog"
        },
        build = ":MasonUpdate",
        opts = {
            ui = {
                icons = {
                    package_installed = "✓",
                    package_uninstalled = "✗",
                    package_pending = "⟳",
                },
            },
        },
        config = function(_, opts)
            require("mason").setup(opts)

            local mr = require("mason-registry")
            local function ensure_installed()
                for _, tool in ipairs(opts.ensure_installed) do
                local p = mr.get_package(tool)
                    if not p:is_installed() then
                        p:install()
                    end
                end
            end

            if mr.refresh then
                mr.refresh(ensure_installed)
            else
                ensure_installed()
            end

            -- mason additional plugins
            for _, plugin in ipairs { "mason-lspconfig", "mason-null-ls", "mason-nvim-dap" } do
                pcall(require, plugin)
            end
        end,
    },
}
