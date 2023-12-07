return {
    'nvim-lualine/lualine.nvim',
    cond = feature_level(2),
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    },
    event = 'VeryLazy',
    opts = function()
        local utils = require 'utils'
        local icons = require 'utils.icons'
        local lsp = require 'utils.lsp'
        local format = require 'utils.format'
        local lint = require 'utils.lint'
        local shell = require 'utils.shell'
        local settings = require 'utils.settings'
        local toggles = require 'utils.toggles'

        --- Extracts the color and attributes from a highlight group.
        ---@param name string
        local function color(name)
            local hl = utils.hl(name)

            if not hl then
                return nil
            end

            local fg = hl.fg or hl.foreground
            local attrs = {}

            for _, attr in ipairs { 'italic', 'bold', 'undercurl', 'underdotted', 'underlined', 'strikethrough' } do
                if hl[attr] then
                    table.insert(attrs, attr)
                end
            end

            return { fg = string.format('#%06x', fg), gui = table.concat(attrs, ',') }
        end

        --- Formats a list of items into a string with a cut-off
        ---@param prefix string # The prefix to add to the string
        ---@param list string[]|string # The list of items to format
        ---@param min? number # The minimum width of the string
        local function sexify(prefix, list, min)
            min = min or 150

            local col = vim.api.nvim_get_option 'columns'
            if col < min then
                return prefix
            end

            return prefix .. ' ' .. utils.tbl_join(utils.to_list(list), ' ' .. icons.TUI.ListSeparator .. ' ')
        end

        local copilot_colors = {
            ['Normal'] = 'CopilotIdle',
            ['InProgress'] = 'CopilotFetching',
            ['Warning'] = 'CopilotWarning',
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
                        settings.transient(function()
                            local prefix, tasks = shell.progress()

                            local tasks_names = tasks
                                and vim.tbl_map(function(task)
                                    ---@cast task utils.shell.RunningProcess
                                    return task.cmd .. ' ' .. utils.tbl_join(task.args, ' ')
                                end, tasks)

                            if prefix and tasks_names then
                                return sexify(prefix, tasks_names)
                            end

                            return nil
                        end),
                        cond = settings.transient(function()
                            return shell.progress() ~= nil
                        end),
                        color = color 'ShellProgressStatus',
                    },
                    {
                        settings.transient(function(buffer)
                            local prefix = icons.UI.Disabled
                            if settings.global.auto_linting_enabled and settings.buf[buffer].auto_linting_enabled then
                                prefix = lint.progress(buffer) or icons.UI.Format
                            end

                            return sexify(prefix, lint.active_names_for_buffer(buffer))
                        end),
                        cond = settings.transient(function(buffer)
                            return lint.active_for_buffer(buffer)
                        end),
                        color = settings.transient(function(buffer)
                            if not settings.global.auto_linting_enabled and settings.buf[buffer].auto_linting_enabled then
                                return color 'DisabledLintersStatus'
                            else
                                return color 'ActiveLintersStatus'
                            end
                        end),
                        separator = false,
                    },
                    {
                        settings.transient(function(buffer)
                            local prefix = icons.UI.Disabled
                            if settings.global.auto_formatting_enabled and settings.buf[buffer].auto_formatting_enabled then
                                prefix = format.progress(buffer) or icons.UI.Lint
                            end

                            return sexify(prefix, format.active_names_for_buffer(buffer))
                        end),
                        cond = settings.transient(function(buffer)
                            return format.active_for_buffer(buffer)
                        end),
                        color = settings.transient(function(buffer)
                            if not settings.global.auto_formatting_enabled and settings.buf[buffer].auto_formatting_enabled then
                                return color 'DisabledFormattersStatus'
                            else
                                return color 'ActiveFormattersStatus'
                            end
                        end),
                        on_click = function()
                            vim.cmd 'ConformInfo'
                        end,
                        separator = false,
                    },
                    {
                        settings.transient(function(buffer)
                            local prefix = lsp.progress() or icons.UI.LSP
                            return sexify(prefix, lsp.active_names_for_buffer(buffer))
                        end),
                        cond = settings.transient(function(buffer)
                            return lsp.any_active_for_buffer(buffer)
                        end),
                        color = color 'ActiveLSPsStatus',
                        on_click = function()
                            vim.cmd 'LspInfo'
                        end,
                    },
                    {
                        settings.transient(function()
                            return sexify(icons.Symbols.Copilot, require('copilot.api').status.data.message or '')
                        end),
                        cond = settings.transient(function(buffer)
                            return lsp.is_active_for_buffer(buffer, 'copilot')
                        end),
                        color = settings.transient(function()
                            return color(copilot_colors[require('copilot.api').status.data.status] or copilot_colors['Normal'])
                        end),
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
                        color = color 'Debug',
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
                        function()
                            return settings.global.ignore_hidden_files and icons.UI.IgnoreHidden or icons.UI.ShowHidden
                        end,
                        color = function()
                            return settings.global.ignore_hidden_files and color 'IgnoreHiddenFilesStatus' or color 'ShowHiddenFilesStatus'
                        end,
                        on_click = function()
                            toggles.toggle_ignore_hidden_files()
                        end,
                    },
                    {
                        require('lazy.status').updates,
                        cond = require('lazy.status').has_updates,
                        color = color 'UpdatesAvailableStatus',
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
}
