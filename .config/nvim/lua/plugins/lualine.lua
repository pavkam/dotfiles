return {
    "nvim-lualine/lualine.nvim",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    event = "VeryLazy",
    opts = function()
        local ui = require "utils.ui"
        local icons = require "utils.icons"
        local lsp = require "utils.lsp"
        local format = require "utils.format"
        local lint = require "utils.lint"

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
                lualine_b = {
                    {
                        "branch",
                        on_click = function()
                            vim.cmd("Telescope git_branches")
                        end
                    },
                },
                lualine_c = {
                    {
                        "diagnostics",
                        symbols = {
                            error = icons.Diagnostics.LSP.Error,
                            warn = icons.Diagnostics.LSP.Warn,
                            info = icons.Diagnostics.LSP.Info,
                            hint = icons.Diagnostics.LSP.Hint,
                        },
                        on_click = function()
                            vim.cmd("Telescope diagnostics")
                        end
                    },
                    { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
                    { "filename", path = 1, symbols = { modified = " " .. icons.ui.Dirty .. " ", readonly = "", unnamed = "" } },
                },
                lualine_x = {
                     {
                        function()
                            return ui.sexy_list(lint.active_names_for_buffer(), icons.ui.Lint)
                        end,
                        cond = function()
                            return lint.active_for_buffer()
                        end,
                        color = ui.hl_fg_color("DiagnosticWarn"),
                    },
                    {
                        function()
                            return ui.sexy_list(format.active_names_for_buffer(), icons.ui.Format)
                        end,
                        cond = function()
                            return format.active_for_buffer()
                        end,
                        color = ui.hl_fg_color("DiagnosticOk"),
                        on_click = function()
                            vim.cmd("ConformInfo")
                        end
                    },
                    {
                        function()
                            return ui.sexy_list(lsp.active_names_for_buffer(), icons.ui.LSP)
                        end,
                        cond = function()
                            return lsp.active_for_buffer()
                        end,
                        color = ui.hl_fg_color("Title"),
                        on_click = function()
                            vim.cmd("LspInfo")
                        end
                    },
                    {
                        function()
                            local status = require("copilot.api").status.data
                            return icons.Symbols.Copilot .. (status.message or "")
                        end,
                        cond = function()
                            return lsp.is_active_for_buffer("copilot")
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
                        function()
                            return require("noice").api.status.command.get()
                        end,
                        cond = function()
                            return package.loaded["noice"] and require("noice").api.status.command.has()
                        end,
                        color = ui.hl_fg_color("Statement"),
                    },
                    {
                        function()
                            return require("noice").api.status.mode.get()
                        end,
                        cond = function()
                            return package.loaded["noice"] and require("noice").api.status.mode.has()
                        end,
                        color = ui.hl_fg_color("Constant"),
                    },
                    {
                        function() return icons.ui.Debugger .. "  " .. require("dap").status() end,
                        cond = function ()
                            return package.loaded["dap"] and require("dap").status() ~= ""
                        end,
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
                        return icons.ui.Clock .. " " .. os.date("%R")
                    end,
                },
            },
            extensions = { "neo-tree", "lazy" },
        }
    end
}
