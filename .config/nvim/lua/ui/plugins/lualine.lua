return {
    'nvim-lualine/lualine.nvim',
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    },
    event = 'UIEnter',
    opts = function()
        local utils = require 'core.utils'
        local icons = require 'ui.icons'
        local lsp = require 'project.lsp'
        local format = require 'formatting'
        local lint = require 'linting'
        local shell = require 'core.shell'
        local settings = require 'core.settings'
        local ui = require 'ui'
        local progress = require 'ui.progress'

        --- Cuts off a string if it is too long
        ---@param str string # The string to cut off
        ---@param max number|nil # The maximum length of the string
        ---@return string # The cut-off string
        local function delongify(str, max)
            max = max or 40

            if #str > max then
                return str:sub(1, max - 1) .. icons.TUI.Ellipsis
            end

            return str
        end

        --- Formats a list of items into a string with a cut-off
        ---@param prefix string # The prefix to add to the string
        ---@param list string[]|string # The list of items to format
        ---@param collapse_max number|nil # The minimum width of the screen to show the full list
        ---@param len_max number|nil # The maximum length of the string
        local function sexify(prefix, list, len_max, collapse_max)
            collapse_max = collapse_max or 150

            local col = vim.api.nvim_get_option_value('columns', {})
            if col < collapse_max then
                return prefix
            end

            return delongify(
                prefix .. ' ' .. table.concat(utils.to_list(list), ' ' .. icons.TUI.ListSeparator .. ' '),
                len_max
            )
        end

        local copilot_colors = {
            ['Normal'] = 'CopilotIdle',
            ['InProgress'] = 'CopilotFetching',
            ['Warning'] = 'CopilotWarning',
        }

        local macro_recording_fmt = icons.UI.Macro
            .. ' Recording macro as '
            .. icons.TUI.StrongPrefix
            .. '%s'
            .. icons.TUI.StrongSuffix
            .. ' '
            .. icons.TUI.Ellipsis

        return {
            options = {
                theme = 'auto',
                globalstatus = true,
            },
            sections = {
                lualine_a = {
                    { 'mode' },
                    {
                        settings.transient(function()
                            local spinner, register = progress.status 'recording_macro'
                            return spinner and sexify(spinner, string.format(macro_recording_fmt, register))
                        end),
                        cond = settings.transient(function()
                            return progress.status 'recording_macro' ~= nil
                        end),
                        color = utils.hl_fg_color_and_attrs 'RecordingMacroStatus',
                    },
                },
                lualine_b = {
                    {
                        'branch',
                        on_click = function()
                            vim.cmd 'Telescope git_branches'
                        end,
                    },
                    {
                        'filetype',
                        icon_only = true,
                        separator = '',
                        padding = { left = 1, right = 0 },
                        on_click = function()
                            vim.cmd 'Buffer'
                        end,
                    },
                    {
                        'filename',
                        path = 1,
                        symbols = {
                            modified = ' ' .. icons.Files.Modified .. ' ',
                            readonly = '',
                            unnamed = '',
                        },
                        padding = { left = 0, right = 1 },
                        on_click = function()
                            vim.cmd 'Buffer'
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
                },
                lualine_x = {
                    {
                        function()
                            local spinner, msg = progress.status 'neotest'
                            return spinner and sexify(spinner, msg)
                        end,
                        cond = settings.transient(function()
                            return progress.status 'neotest' ~= nil
                        end),
                        color = utils.hl_fg_color_and_attrs 'AuxiliaryProgressStatus',
                    },
                    {
                        function()
                            local spinner, msg = progress.status 'package-info'
                            return spinner and sexify(spinner, msg)
                        end,
                        cond = settings.transient(function()
                            return progress.status 'package-info' ~= nil
                        end),
                        color = utils.hl_fg_color_and_attrs 'AuxiliaryProgressStatus',
                    },
                    {
                        settings.transient(function()
                            local prefix, tasks = shell.progress()

                            ---@type string[]|nil
                            local tasks_names = tasks
                                and vim.iter(tasks)
                                    :map(
                                        ---@param task core.shell.RunningProcess
                                        function(task)
                                            return task.cmd .. ' ' .. table.concat(task.args, ' ')
                                        end
                                    )
                                    :totable()

                            if prefix and tasks_names then
                                return sexify(prefix, tasks_names, 70)
                            end

                            return nil
                        end),
                        cond = settings.transient(function()
                            return shell.progress() ~= nil
                        end),
                        color = utils.hl_fg_color_and_attrs 'AuxiliaryProgressStatus',
                    },
                    {
                        settings.transient(function(buffer)
                            local prefix = icons.UI.Disabled
                            if lint.enabled(buffer) then
                                prefix = lint.progress(buffer) or icons.UI.Format
                            end

                            return sexify(prefix, lint.active_names_for_buffer(buffer))
                        end),
                        cond = settings.transient(function(buffer)
                            return lint.active_for_buffer(buffer)
                        end),
                        color = settings.transient(function(buffer)
                            if not lint.enabled(buffer) then
                                return utils.hl_fg_color_and_attrs 'DisabledLintersStatus'
                            else
                                return utils.hl_fg_color_and_attrs 'ActiveLintersStatus'
                            end
                        end),
                        separator = false,
                    },
                    {
                        settings.transient(function(buffer)
                            local prefix = icons.UI.Disabled
                            if format.enabled(buffer) then
                                prefix = format.progress(buffer) or icons.UI.Lint
                            end

                            return sexify(prefix, format.active_names_for_buffer(buffer))
                        end),
                        cond = settings.transient(function(buffer)
                            return format.active_for_buffer(buffer)
                        end),
                        color = settings.transient(function(buffer)
                            if not format.enabled(buffer) then
                                return utils.hl_fg_color_and_attrs 'DisabledFormattersStatus'
                            else
                                return utils.hl_fg_color_and_attrs 'ActiveFormattersStatus'
                            end
                        end),
                        on_click = function()
                            vim.cmd 'ConformInfo'
                        end,
                        separator = false,
                    },
                    {
                        function()
                            local spinner, msg = progress.status 'workspace'
                            return spinner and sexify(spinner, msg)
                        end,
                        cond = function()
                            return progress.status 'workspace' ~= nil
                        end,
                        color = utils.hl_fg_color_and_attrs 'ActiveLSPsStatus',
                    },
                    {
                        settings.transient(function(buffer)
                            local prefix = lsp.progress() or icons.UI.LSP
                            return sexify(prefix, lsp.active_names_for_buffer(buffer))
                        end),
                        cond = settings.transient(function(buffer)
                            return lsp.any_active_for_buffer(buffer)
                        end),
                        color = utils.hl_fg_color_and_attrs 'ActiveLSPsStatus',
                        on_click = function()
                            vim.cmd 'LspInfo'
                        end,
                    },
                    package.loaded['copilot.nvim']
                            and {
                                settings.transient(function()
                                    return sexify(
                                        icons.Symbols.Copilot,
                                        require('copilot.api').status.data.message or ''
                                    )
                                end),
                                cond = settings.transient(function(buffer)
                                    return lsp.is_active_for_buffer(buffer, 'copilot')
                                end),
                                color = settings.transient(function()
                                    return utils.hl_fg_color_and_attrs(
                                        copilot_colors[require('copilot.api').status.data.status]
                                            or copilot_colors['Normal']
                                    )
                                end),
                            }
                        or nil,
                },
                lualine_y = {
                    {
                        function()
                            return icons.UI.Debugger .. '  ' .. require('dap').status()
                        end,
                        cond = function()
                            return package.loaded['dap'] and require('dap').status() ~= ''
                        end,
                        color = utils.hl_fg_color_and_attrs 'Debug',
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
                            return ui.ignore_hidden_files.active() and icons.UI.IgnoreHidden or icons.UI.ShowHidden
                        end,
                        color = utils.hl_fg_color_and_attrs 'Comment',
                        on_click = function()
                            ui.ignore_hidden_files.toggle()
                        end,
                        separator = false,
                    },
                    {
                        function()
                            return icons.UI.TMux
                        end,
                        color = utils.hl_fg_color_and_attrs 'Comment',
                        cond = require('ui.tmux').socket() ~= nil,
                        separator = false,
                    },
                    {
                        function()
                            return icons.UI.SpellCheck
                        end,
                        color = utils.hl_fg_color_and_attrs 'Comment',
                        cond = function()
                            return vim.o.spell
                        end,
                        separator = false,
                    },
                    {
                        function()
                            return icons.UI.TypoCheck
                        end,
                        cond = settings.transient(function(buffer)
                            return lsp.is_active_for_buffer(buffer, 'typos_lsp')
                        end),
                        color = utils.hl_fg_color_and_attrs 'Comment',
                    },
                    {
                        require('lazy.status').updates,
                        cond = require('lazy.status').has_updates,
                        color = utils.hl_fg_color_and_attrs 'Comment',
                        on_click = function()
                            vim.cmd 'Lazy'
                        end,
                    },
                    { 'progress', separator = ' ', padding = { left = 1, right = 0 } },
                    { 'location', padding = { left = 0, right = 1 } },
                },
            },
            extensions = { 'neo-tree', 'lazy', 'man', 'mason', 'nvim-dap-ui', 'quickfix' },
        }
    end,
}
