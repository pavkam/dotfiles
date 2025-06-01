local icons = require 'icons'
local lsp = require 'lsp'
local shell = require 'shell'
local settings = require 'settings'
local progress = require 'progress'

---@module 'symb'

---@class ui.lualine.sections
local M = {}

---@type icon|nil
local spinner_icon
ide.sched.on_task_monitor_tick(function(tasks, tick)
    spinner_icon = ide.symb.progress.default[tick % #ide.symb.progress.default + 1]
    pcall(require('lualine').refresh --[[@as function]])
end)

local function hl_fg_color_and_attrs(name)
    assert(type(name) == 'string' and name ~= '')

    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })

    if not hl then
        return nil
    end

    local fg = hl.fg or 0
    local attrs = {}

    for _, attr in ipairs { 'italic', 'bold', 'undercurl', 'underdotted', 'underlined', 'strikethrough' } do
        if hl[attr] then
            table.insert(attrs, attr)
        end
    end

    return { fg = string.format('#%06x', fg), gui = table.concat(attrs, ',') }
end

ide.theme.register_highlight_groups {
    AuxiliaryProgressStatus = 'Comment',

    CopilotIdle = 'Special',
    CopilotFetching = 'DiagnosticWarn',
    CopilotWarning = 'DiagnosticError',
    RecordingMacroStatus = { 'Error', { bold = true } },

    StatusLineTestFailed = 'NeotestFailed',
    StatusLineTestPassed = 'NeotestPassed',
    StatusLineTestSkipped = 'NeotestSkipped',
}

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

    return ide.text.abbreviate(
        icons.fit(prefix, 2) .. table.concat(table.to_list(list), ' ' .. icons.fit(icons.TUI.ListSeparator, 2)),
        { max = len_max }
    )
end

-- TODO: refactor this whole mess

local macro_recording_fmt = icons.UI.Macro
    .. ' Recording macro as '
    .. icons.TUI.StrongPrefix
    .. '%s'
    .. icons.TUI.StrongSuffix
    .. ' '
    .. icons.TUI.Ellipsis

---@class ui.lualine.sections.NeotestSummary # The counts of the tests.
---@field total number # the total number of tests
---@field passed number # the number of tests that passed
---@field failed number # the number of tests that failed
---@field skipped number # the number of tests that were skipped

--- Gets the counts of the tests in the given buffer.
---@param buffer number|nil # the buffer to get the counts for, or nil for all buffers.
---@return ui.lualine.sections.NeotestSummary # the counts of the tests.
local function get_neotest_summary(buffer)
    local neotest = require 'neotest'

    ---@type ui.lualine.sections.NeotestSummary
    local result = {
        total = 0,
        passed = 0,
        failed = 0,
        skipped = 0,
    }

    for _, adapter_id in ipairs(neotest.state.adapter_ids()) do
        local counts = neotest.state.status_counts(adapter_id, { buffer = buffer })

        if counts ~= nil then
            for status, count in pairs(result) do
                result[status] = count + counts[status]
            end
        end
    end

    return result
end

local neotest_colors = {
    ['passed'] = 'StatusLineTestPassed',
    ['failed'] = 'StatusLineTestFailed',
    ['skipped'] = 'StatusLineTestSkipped',
}

local copilot_colors = {
    ['Normal'] = 'CopilotIdle',
    ['InProgress'] = 'CopilotFetching',
    ['Warning'] = 'CopilotWarning',
}

local components = {
    --- The section that shows the current git branch.
    branch = {
        'branch',
        on_click = function()
            vim.cmd 'Telescope git_branches'
        end,
    },

    --- The section that shows the current file type.
    file_type = {
        'filetype',
        icon_only = true,
        on_click = function()
            vim.cmd 'Debug'
        end,
        separator = '',
    },

    --- The section that shows the current macro being recorded.
    macro = {
        settings.transient(function()
            local spinner, register = progress.status 'recording_macro'
            return spinner and sexify(spinner, string.format(macro_recording_fmt, register))
        end),
        cond = settings.transient(function()
            return progress.status 'recording_macro' ~= nil
        end),
        color = hl_fg_color_and_attrs 'RecordingMacroStatus',
    },

    --- The section that shows the current file name.
    file_name = {
        'filename',
        path = 1,
        symbols = {
            modified = icons.fit(icons.Files.Modified, 2),
            readonly = '',
            unnamed = '',
        },
        fmt = function(name)
            local root = require('project').root(0, false)

            if not root then
                return name
            end

            return ide.fs.format_relative_path(root, vim.api.nvim_buf_get_name(0), { include_base_dir = true })
        end,
        on_click = function()
            vim.cmd 'Debug'
        end,
    },

    --- The section that shows diagnostics.
    diagnostics = {
        'diagnostics',
        symbols = {
            error = icons.fit(icons.Diagnostics.LSP.Error, 2),
            warn = icons.fit(icons.Diagnostics.LSP.Warn, 2),
            info = icons.fit(icons.Diagnostics.LSP.Info, 2),
            hint = icons.fit(icons.Diagnostics.LSP.Hint, 2),
        },
        on_click = function()
            vim.cmd 'Telescope diagnostics'
        end,
    },

    -- TODO: the tests do not show up in the statusline after first run
    -- The section that shows the status of neo-test.
    neotest = {
        settings.transient(function(buffer)
            local spinner, msg = progress.status 'neotest'
            if spinner then
                return spinner and sexify(spinner, msg)
            end

            local summary = get_neotest_summary(buffer)
            local config = require 'neotest.config'

            msg = string.format('%s %d', icons.UI.Test, summary.total)
            for status, count in pairs(summary) do
                if count > 0 and status ~= 'total' then
                    msg = string.format(
                        '%s %s %%#%s#%s %d',
                        msg,
                        icons.TUI.ListSeparator,
                        neotest_colors[status],
                        config.icons[status],
                        count
                    )
                end
            end

            return msg
        end),
        cond = settings.transient(function(buffer)
            return progress.status 'neotest' ~= nil or get_neotest_summary(buffer).total > 0
        end),
        -- color = settings.transient(function(buffer)
        --     if progress.status 'neotest' ~= nil then
        --         return hl.hl_fg_color_and_attrs 'AuxiliaryProgressStatus'
        --     end
        --
        --     local summary = get_neotest_summary(buffer)
        --
        --     if summary.failed > 0 then
        --         return hl.hl_fg_color_and_attrs 'NeotestFailed'
        --     elseif summary.passed > 0 then
        --         return hl.hl_fg_color_and_attrs 'NeotestPassed'
        --     else
        --         return hl.hl_fg_color_and_attrs 'NeotestTest'
        --     end
        -- end),
    },

    --- The section that shows the status of the shell processes.
    shell = {
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
        color = hl_fg_color_and_attrs 'AuxiliaryProgressStatus',
    },

    --- The section that shows the status of running tools.
    tools = {
        function()
            local buffer = ide.buf.current
            if not buffer then
                return nil
            end

            return table.concat(
                table.list_map(buffer.tools, function(tool)
                    ---@type icon|nil
                    local icon = ide.symb.tool[tool.type][tool.name]
                    if tool.running then
                        icon = icon and spinner_icon and spinner_icon.replace_hl(icon) or spinner_icon
                    end

                    if not icon or not tool.enabled then
                        icon = ide.symb.state.disabled
                    end

                    return ide.tui.stl_format(icon.fit(2), tool.name)
                end),
                ' '
            )
        end,
        cond = function()
            local buffer = ide.buf.current
            if not buffer then
                return nil
            end

            return #buffer.tools > 0
        end,
    },

    --- The section that shows the status of the copilot.
    copilot = ide.plugin.has 'copilot.lua' and {
        settings.transient(function()
            return sexify(icons.Symbols.Copilot, require('copilot.api').status.data.message or '')
        end),
        cond = settings.transient(function(buffer)
            return lsp.is_active_for_buffer(buffer, 'copilot')
        end),
        color = settings.transient(function()
            return hl_fg_color_and_attrs(
                copilot_colors[require('copilot.api').status.data.status] or copilot_colors['Normal']
            )
        end),
    } or nil,

    --- The section that shows the status of the debugger.
    debugger = {
        function()
            return icons.UI.Debugger .. '  ' .. require('dap').status()
        end,
        cond = function()
            return package.loaded['dap'] and require('dap').status() ~= ''
        end,
        color = hl_fg_color_and_attrs 'Debug',
    },

    --- The section that shows the status of the git diff.
    diff = {
        'diff',
        symbols = {
            added = icons.fit(icons.Git.Added, 2),
            modified = icons.fit(icons.Git.Modified, 2),
            removed = icons.fit(icons.Git.Removed, 2),
        },
        source = function()
            ---@type table<string, number>|nil
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

    --- The section that shows the status of hidden files.
    ignore_hidden_files = {
        function()
            return ide.tui.ignore_hidden_files.active() and icons.UI.IgnoreHidden or icons.UI.ShowHidden
        end,
        color = hl_fg_color_and_attrs 'Comment',
        on_click = function()
            ide.tui.ignore_hidden_files.toggle()
        end,
    },

    --- The section that shows the status of tmux.
    tmux = {
        function()
            return icons.UI.TMux
        end,
        color = hl_fg_color_and_attrs 'Comment',
        cond = function()
            return require('tmux').socket() ~= nil
        end,
        on_click = function()
            require('tmux').manage_sessions()
        end,
    },

    --- The section that shows the status of spell checking.
    spell_check = {
        function()
            return icons.UI.SpellCheck
        end,
        color = hl_fg_color_and_attrs 'Comment',
        cond = function()
            return vim.o.spell
        end,
    },

    --- The section that shows the status of typo checking.
    typo_check = {
        function()
            return icons.UI.TypoCheck
        end,
        cond = settings.transient(function(buffer)
            return lsp.is_active_for_buffer(buffer, 'typos_lsp')
        end),
        color = hl_fg_color_and_attrs 'Comment',
    },

    --- The section that shows the status of updates.
    lazy_updates = {
        require('lazy.status').updates,
        cond = require('lazy.status').has_updates,
        color = hl_fg_color_and_attrs 'Comment',
        on_click = function()
            vim.cmd 'Lazy'
        end,
    },

    --- The section that shows the buffer list.
    buffers = {
        'buffers',
        mode = 2,
        symbols = {
            modified = icons.fit(icons.Files.Modified, 2, true),
            alternate_file = icons.fit(icons.Files.Previous, 2),
            directory = icons.fit(icons.Files.OpenFolder, 2, true),
        },
        use_mode_colors = true,
        filetype_names = {
            ['neo-tree'] = 'File System',
        },
        fmt = function(name)
            return ide.text.abbreviate(name, { max = 30 })
        end,
    },

    --- The section that shows the tab list.
    tabs = { 'tabs' },

    --- The section that shows the current mode.
    mode = { 'mode' },

    --- The section that shows the current location in the buffer.
    location_in_buffer = { 'progress' },

    --- The section that shows the current position in the buffer.
    position_in_buffer = { 'location' },
}

M.extensions = {
    'neo-tree',
    'lazy',
    'man',
    'mason',
    {
        init = function()
            vim.g.qf_disable_statusline = true
        end,
        winbar = {
            lualine_b = {
                {
                    function()
                        return icons.fit(icons.UI.Fix, 2)
                    end,
                    separator = false,
                    padding = { right = 0 },
                },
                {
                    function()
                        local _, type = require('qf').details()
                        return type == 'l' and 'Location List' or 'Quickfix List'
                    end,
                    padding = { left = 0 },
                },
            },
            lualine_c = {
                function()
                    local details = require('qf').details()
                    return details and details.title
                end,
            },
            lualine_z = {
                function()
                    local details = require('qf').details()
                    return details and string.format('%d of %d', details.idx, details.size)
                end,
            },
        },
        filetypes = { 'qf' },
    },
    {
        winbar = {
            lualine_c = {
                {
                    function()
                        return icons.fit(icons.UI.Debugger, 2)
                    end,
                    separator = false,
                    padding = { right = 0 },
                },
                {
                    'filename',
                    file_status = false,
                    padding = { left = 0 },
                },
            },
        },
        filetypes = {
            'dapui_console',
            'dapui_watches',
            'dapui_stacks',
            'dapui_breakpoints',
            'dapui_scopes',
        },
    },
    {
        winbar = {
            lualine_c = {
                {
                    function()
                        return icons.fit(icons.UI.Test, 2)
                    end,
                    separator = false,
                    padding = { right = 0 },
                },
                {
                    'filename',
                    file_status = false,
                    padding = { left = 0 },
                },
            },
        },
        filetypes = {
            'neotest-summary',
            'neotest-output-panel',
        },
    },
    {
        winbar = {
            lualine_c = {
                {
                    function()
                        return icons.fit(icons.UI.Help, 2)
                    end,
                    color = '@comment.note',
                    separator = false,
                    padding = { right = 0 },
                },
                {
                    'filename',
                    file_status = false,
                    padding = { left = 0 },
                },
            },
        },
        filetypes = {
            'help',
        },
    },
    {
        winbar = {
            lualine_c = {
                {
                    function()
                        return icons.fit(icons.UI.Tree, 2)
                    end,
                    color = '@comment.note',
                    separator = false,
                    padding = { right = 0 },
                },
                {
                    'filename',
                    file_status = false,
                    padding = { left = 0 },
                },
            },
        },
        filetypes = {
            'query',
        },
    },
}

--- The tab-line section.
M.tab_line = {
    lualine_a = {
        components.branch,
        table.merge(components.file_type, { padding = { left = 1, right = 0 } }),
        components.diff,
        components.diagnostics,
    },
    lualine_b = {
        components.buffers,
    },
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = { components.tabs },
}

--- The status-line section.
M.status_line = {
    lualine_a = {
        components.mode,
        components.macro,
    },
    lualine_b = {
        table.merge(components.copilot, { separator = false, padding = { left = 1, right = 0 } }),
    },
    lualine_c = {
        components.tools,
        components.neotest,
        components.shell,
    },
    lualine_x = {},
    lualine_y = {
        components.debugger,
    },
    lualine_z = {
        table.merge(components.ignore_hidden_files, { separator = false }),
        table.merge(components.tmux, { separator = false }),
        table.merge(components.spell_check, { separator = false }),
        table.merge(components.typo_check, { separator = false }),
        components.lazy_updates,
        table.merge(components.location_in_buffer, { separator = ' ', padding = { left = 1, right = 0 } }),
        table.merge(components.position_in_buffer, { left = 0, right = 1 }),
    },
}

--- The win-bar section.
M.win_bar = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {
        table.merge(components.file_type, { padding = { right = 0 } }),
        table.merge(components.file_name, { padding = { left = 0 } }),
    },
    lualine_x = {},
    lualine_y = {
        -- TODO: make this sexier
        function()
            return require('nvim-treesitter').statusline {
                indicator_size = 70,
                type_patterns = { 'class', 'function', 'method' },
                separator = ' -> ',
            }
        end,
    },
    lualine_z = { components.diagnostics },
}

-- inactive win-bar is the same as the win-bar.
M.inactive_win_bar = M.win_bar

return M
