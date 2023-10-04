return {
    "nvim-lualine/lualine.nvim",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "nvim-neo-tree/neo-tree.nvim",
    },
    event = "VeryLazy",
    opts = function()
        local ui = require "utils.ui"
        local icons = require "utils.icons"
        local lsp = require "utils.lsp"

        local copilot_colors = {
            [""] = ui.hl_fg_color("Special"),
            ["Normal"] = ui.hl_fg_color("Special"),
            ["Warning"] = ui.hl_fg_color("DiagnosticError"),
            ["InProgress"] = ui.hl_fg_color("DiagnosticWarn"),
        }

        return {
            options = {
                theme = "auto",
                globalstatus = true,
                disabled_filetypes = { statusline = { "dashboard", "alpha" } },
            },
            sections = {
                lualine_a = { "mode" },
                lualine_b = { "branch" },
                lualine_c = {
                    {
                        "diagnostics",
                        symbols = {
                            error = icons.diagnostics.Error,
                            warn = icons.diagnostics.Warn,
                            info = icons.diagnostics.Info,
                            hint = icons.diagnostics.Hint,
                        },
                    },
                    { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
                    { "filename", path = 1, symbols = { modified = " " .. icons.ui.Dirty .. " ", readonly = "", unnamed = "" } },
                },
                lualine_x = {
                    {
                        function() return icons.ui.LSP .. "  " .. lsp.client_names() end,
                        cond = function() return #vim.lsp.get_active_clients() > 0 end,
                        color = ui.hl_fg_color("Comment"),
                    },
                    {
                        function()
                            local icon = icons.cmp_categories.Copilot
                            local status = require("copilot.api").status.data
                            return icon .. (status.message or "")
                        end,
                        cond = function()
                            local ok, clients = pcall(vim.lsp.get_active_clients, { name = "copilot", bufnr = 0 })
                            return ok and #clients > 0
                        end,
                        color = function()
                            if not package.loaded["copilot"] then
                                return
                            end
                            local status = require("copilot.api").status.data
                            return copilot_colors[status.status] or copilot_colors[""]
                        end,
                    },
                    {
                        function() return require("noice").api.status.command.get() end,
                        cond = function() return package.loaded["noice"] and require("noice").api.status.command.has() end,
                        color = ui.hl_fg_color("Statement"),
                    },
                    {
                        function() return require("noice").api.status.mode.get() end,
                        cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has() end,
                        color = ui.hl_fg_color("Constant"),
                    },
                    {
                        function() return icons.ui.Debugger .. "  " .. require("dap").status() end,
                        cond = function () return package.loaded["dap"] and require("dap").status() ~= "" end,
                        color = ui.hl_fg_color("Debug"),
                    },
                    {
                        "diff",
                        symbols = {
                            added = icons.git.Added,
                            modified = icons.git.Modified,
                            removed = icons.git.Removed,
                        },
                    },
                },
                lualine_y = {
                    { "progress", separator = " ", padding = { left = 1, right = 0 } },
                    { "location", padding = { left = 0, right = 1 } },
                },
                lualine_z = {
                    function()
                        return icons.ui.Clock .. os.date("%R")
                    end,
                },
            },
            extensions = { "neo-tree", "lazy" },
        }
    end
}
