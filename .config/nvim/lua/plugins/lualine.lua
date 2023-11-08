return {
    'nvim-lualine/lualine.nvim',
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    },
    event = 'VeryLazy',
    opts = function()
        local ui = require 'utils.ui'
        local icons = require 'utils.icons'
        local lsp = require 'utils.lsp'
        local format = require 'utils.format'
        local lint = require 'utils.lint'
        local settings = require 'utils.settings'

        local copilot_colors = {
            ['Normal'] = ui.hl_fg_color 'Special',
            ['Warning'] = ui.hl_fg_color 'DiagnosticError',
            ['InProgress'] = ui.hl_fg_color 'DiagnosticWarn',
        }

        return {
            options = {
                theme = 'auto',
                globalstatus = true,
                disabled_filetypes = { statusline = { 'dashboard', 'alpha' } },
            },
            sections = {
                lualine_a = { 'mode' },
                lualine_b = {
                    {
                        'branch',
                        on_click = function()
                            vim.cmd 'Telescope git_branches'
                        end,
                    },
                },
                lualine_c = {
                    {
                        'diagnostics',
                        symbols = {
                            error = icons.Diagnostics.LSP.Error .. ' ',
                            warn = icons.Diagnostics.LSP.Warn .. ' ',
                            info = icons.Diagnostics.LSP.Info .. ' ',
                            hint = icons.Diagnostics.LSP.Hint .. ' ',
                        },
                        on_click = function()
                            vim.cmd 'Telescope diagnostics'
                        end,
                    },
                    { 'filetype', icon_only = true, separator = '', padding = { left = 1, right = 0 } },
                    {
                        function()
                            local title = vim.fn.win_gettype() == 'loclist' and vim.fn.getloclist(0, { title = 0 }).title
                                or vim.fn.getqflist({ title = 0 }).title
                            if not title or title == '' then
                                title = '<untitled>'
                            end

                            return title
                        end,
                        cond = function()
                            return vim.bo.filetype == 'qf'
                        end,
                        separator = '',
                        padding = { left = 1, right = 1 },
                    },
                    { 'filename', path = 1, symbols = { modified = ' ' .. icons.Files.Modified .. ' ', readonly = '', unnamed = '' } },
                },
                lualine_x = {
                    {
                        settings.transient(function(buffer)
                            return ui.sexy_list(lint.active_names_for_buffer(buffer), icons.UI.Lint)
                        end),
                        cond = settings.transient(function(buffer)
                            return lint.active_for_buffer(buffer)
                        end),
                        color = ui.hl_fg_color 'DiagnosticWarn',
                    },
                    {
                        settings.transient(function(buffer)
                            return ui.sexy_list(format.active_names_for_buffer(buffer), icons.UI.Format)
                        end),
                        cond = settings.transient(function(buffer)
                            return format.active_for_buffer(buffer)
                        end),
                        color = ui.hl_fg_color 'DiagnosticOk',
                        on_click = function()
                            vim.cmd 'ConformInfo'
                        end,
                    },
                    {
                        settings.transient(function(buffer)
                            return ui.sexy_list(lsp.active_names_for_buffer(buffer), icons.UI.LSP)
                        end),
                        cond = settings.transient(function(buffer)
                            return lsp.any_active_for_buffer(buffer)
                        end),
                        color = ui.hl_fg_color 'Title',
                        on_click = function()
                            vim.cmd 'LspInfo'
                        end,
                    },
                    {
                        function()
                            return icons.Symbols.Copilot .. ' ' .. (require('copilot.api').status.data.message or '')
                        end,
                        cond = settings.transient(function(buffer)
                            return lsp.is_active_for_buffer(buffer, 'copilot')
                        end),
                        color = function()
                            return copilot_colors[require('copilot.api').status.data.status] or copilot_colors['Normal']
                        end,
                    },
                },
                lualine_y = {
                    {
                        function()
                            return icons.UI.Debugger .. '  ' .. require('dap').status()
                        end,
                        cond = function()
                            return package.loaded['dap'] and require('dap').status() ~= ''
                        end,
                        color = ui.hl_fg_color 'Debug',
                    },
                    {
                        'diff',
                        symbols = {
                            added = icons.Git.Added .. ' ',
                            modified = icons.Git.Modified .. ' ',
                            removed = icons.Git.Removed .. ' ',
                        },
                        source = function()
                            ---@diagnostic disable-next-line: undefined-field
                            local gitsigns = vim.b.gitsigns_status_dict

                            if gitsigns then
                                return {
                                    added = gitsigns.added,
                                    modified = gitsigns.changed,
                                    removed = gitsigns.removed,
                                }
                            end
                        end,
                    },
                },
                lualine_z = {
                    {
                        require('lazy.status').updates,
                        cond = require('lazy.status').has_updates,
                        color = ui.hl_fg_color 'Comment',
                        on_click = function()
                            vim.cmd 'Lazy'
                        end,
                    },
                    { 'progress', separator = ' ', padding = { left = 1, right = 0 } },
                    { 'location', padding = { left = 0, right = 1 } },
                },
            },
            extensions = { 'neo-tree', 'lazy' },
        }
    end,
    config = function(_, opts)
        local utils = require 'utils'
        local lualine = require 'lualine'

        lualine.setup(opts)

        utils.on_user_event('CopilotStatusUpdate', function()
            lualine.refresh()
        end)
    end,
}
