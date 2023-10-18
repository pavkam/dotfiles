return {
    "nvim-lualine/lualine.nvim",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    event = "VeryLazy",
    opts = function()
        local utils = require "utils"
        local ui = require "utils.ui"
        local icons = require "utils.icons"
        local lsp = require "utils.lsp"
        local format = require "utils.format"
        local lint = require "utils.lint"

        local copilot_colors = {
            ["Normal"] = ui.hl_fg_color("Special"),
            ["Warning"] = ui.hl_fg_color("DiagnosticError"),
            ["InProgress"] = ui.hl_fg_color("DiagnosticWarn"),
        }

        local function schedule_update_copilot()
            utils.trigger_user_event("CopilotLuaLineUpdate")
        end

        local
            linters_text,
            linters_cond,
            formatters_text,
            formatters_cond,
            lsp_text,
            lsp_cond,
            copilot_cond = utils.event_memoized({ "BufEnter", "LspAttach", "LspDetach" }, "*",
                function(buffer) return ui.sexy_list(lint.active_names_for_buffer(buffer), icons.UI.Lint) end,
                function(buffer) return lint.active_for_buffer(buffer) end,
                function(buffer) return ui.sexy_list(format.active_names_for_buffer(buffer), icons.UI.Format) end,
                function(buffer) return format.active_for_buffer(buffer) end,
                function(buffer) return ui.sexy_list(lsp.active_names_for_buffer(buffer), icons.UI.LSP) end,
                function(buffer) return lsp.any_active_for_buffer() end,
                function(buffer)
                    local is_active = lsp.is_active_for_buffer(buffer, "copilot")
                    if is_active then
                        require("copilot.api").register_status_notification_handler(schedule_update_copilot)
                        schedule_update_copilot()
                    end

                    return is_active
                end
            )

        local
            copilot_text,
            copilot_color = utils.user_event_memoized("CopilotLuaLineUpdate",
                function()
                    return icons.Symbols.Copilot .. " " .. (require("copilot.api").status.data.message or "")
                end,
                function()
                    return copilot_colors[require("copilot.api").status.data.status] or copilot_colors["Normal"]
                end
            )

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
                            error = icons.Diagnostics.LSP.Error .. " ",
                            warn = icons.Diagnostics.LSP.Warn .. " ",
                            info = icons.Diagnostics.LSP.Info .. " ",
                            hint = icons.Diagnostics.LSP.Hint .. " ",
                        },
                        on_click = function()
                            vim.cmd("Telescope diagnostics")
                        end
                    },
                    { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
                    { "filename", path = 1, symbols = { modified = " " .. icons.Files.Modified .. " ", readonly = "", unnamed = "" } },
                },
                lualine_x = {
                     {
                        linters_text,
                        cond = linters_cond,
                        color = ui.hl_fg_color("DiagnosticWarn"),
                    },
                    {
                        formatters_text,
                        cond = formatters_cond,
                        color = ui.hl_fg_color("DiagnosticOk"),
                        on_click = function()
                            vim.cmd("ConformInfo")
                        end
                    },
                    {
                        lsp_text,
                        cond = lsp_cond,
                        color = ui.hl_fg_color("Title"),
                        on_click = function()
                            vim.cmd("LspInfo")
                        end
                    },
                    {
                        copilot_text,
                        cond = copilot_cond,
                        color = copilot_color,
                    },
                },
                lualine_y = {
                    {
                        function() return icons.UI.Debugger .. "  " .. require("dap").status() end,
                        cond = function ()
                            return package.loaded["dap"] and require("dap").status() ~= ""
                        end,
                        color = ui.hl_fg_color("Debug"),
                    },
                    {
                        "diff",
                        symbols = {
                            added = icons.Git.Added .. " ",
                            modified = icons.Git.Modified .. " ",
                            removed = icons.Git.Removed .. " ",
                        },
                    },
                },
                lualine_z = {
                     {
                        require("lazy.status").updates,
                        cond = require("lazy.status").has_updates,
                        color = ui.hl_fg_color("Comment"),
                        on_click = function()
                            vim.cmd("Lazy")
                        end
                    },
                    { "progress", separator = " ", padding = { left = 1, right = 0 } },
                    { "location", padding = { left = 0, right = 1 } },
                },
            },
            extensions = { "neo-tree", "lazy" },
        }
    end
}
