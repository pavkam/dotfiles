local icons = require 'ui.icons'
local lsp = require 'project.lsp'
local format = require 'formatting'
local lint = require 'linting'
local shell = require 'core.shell'
local settings = require 'core.settings'
local progress = require 'ui.progress'
local hl = require 'ui.hl'

---@class ui.lualine.sections
local M = {}

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
        icons.fit(prefix, 2) .. table.concat(vim.to_list(list), ' ' .. icons.fit(icons.TUI.ListSeparator, 2)),
        len_max
    )
end

local macro_recording_fmt = icons.UI.Macro
    .. ' Recording macro as '
    .. icons.TUI.StrongPrefix
    .. '%s'
    .. icons.TUI.StrongSuffix
    .. ' '
    .. icons.TUI.Ellipsis

--- The section that shows the current macro being recorded
M.macro = {
    settings.transient(function()
        local spinner, register = progress.status 'recording_macro'
        return spinner and sexify(spinner, string.format(macro_recording_fmt, register))
    end),
    cond = settings.transient(function()
        return progress.status 'recording_macro' ~= nil
    end),
    color = hl.hl_fg_color_and_attrs 'RecordingMacroStatus',
}

--- The section that shows the current git branch
M.branch = {
    'branch',
    on_click = function()
        vim.cmd 'Telescope git_branches'
    end,
}

--- The section that shows the file type
M.file_type = {
    'filetype',
    icon_only = true,
    on_click = function()
        vim.cmd 'Buffer'
    end,
}

--- The section that shows the current file name
M.file_name = {
    'filename',
    path = 1,
    symbols = {
        modified = ' ' .. icons.Files.Modified .. ' ',
        readonly = '',
        unnamed = '',
    },
    on_click = function()
        vim.cmd 'Buffer'
    end,
}

--- The section that shows diagnostics
M.diagnostics = {
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
}

---@class ui.lualine.sections.neotest_summary
---@field total number # The total number of tests
---@field passed number # The number of tests that passed
---@field failed number # The number of tests that failed
---@field skipped number # The number of tests that were skipped

--- Gets the counts of the tests in the given buffer
---@param buffer number|nil # The buffer to get the counts for, or nil for all buffers
---@return ui.lualine.sections.neotest_summary # The counts of the tests
local function get_neotest_summary(buffer)
    local neotest = require 'neotest'

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

--- The section that shows the status of neo-test
M.neotest = {
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
                msg = string.format('%s %s %s %d', msg, icons.TUI.ListSeparator, config.icons[status], count)
            end
        end

        return msg
    end),
    cond = settings.transient(function(buffer)
        return progress.status 'neotest' ~= nil or get_neotest_summary(buffer).total > 0
    end),
    color = settings.transient(function(buffer)
        if progress.status 'neotest' ~= nil then
            return hl.hl_fg_color_and_attrs 'AuxiliaryProgressStatus'
        end

        local summary = get_neotest_summary(buffer)

        if summary.failed > 0 then
            return hl.hl_fg_color_and_attrs 'NeotestFailed'
        elseif summary.passed > 0 then
            return hl.hl_fg_color_and_attrs 'NeotestPassed'
        else
            return hl.hl_fg_color_and_attrs 'NeotestTest'
        end
    end),
}

--- The section that shows the status of package-info
M.package_info = {
    function()
        local spinner, msg = progress.status 'package-info'
        return spinner and sexify(spinner, msg)
    end,
    cond = settings.transient(function()
        return progress.status 'package-info' ~= nil
    end),
    color = hl.hl_fg_color_and_attrs 'AuxiliaryProgressStatus',
}

--- The section that shows the status of the shell processes
M.shell = {
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
    color = hl.hl_fg_color_and_attrs 'AuxiliaryProgressStatus',
}

--- The section that shows the status of the linters
M.linting = {
    settings.transient(function(buffer)
        local prefix = icons.UI.Disabled
        if lint.enabled(buffer) then
            prefix = lint.progress(buffer) or icons.UI.Format
        end

        return sexify(prefix, lint.active(buffer))
    end),
    cond = settings.transient(function(buffer)
        return #lint.active(buffer) > 0
    end),
    color = settings.transient(function(buffer)
        if not lint.enabled(buffer) then
            return hl.hl_fg_color_and_attrs 'DisabledLintersStatus'
        else
            return hl.hl_fg_color_and_attrs 'ActiveLintersStatus'
        end
    end),
}

--- The section that shows the status of the formatters
M.formatting = {
    settings.transient(function(buffer)
        local prefix = icons.UI.Disabled
        if format.enabled(buffer) then
            prefix = format.progress(buffer) or icons.UI.Lint
        end

        return sexify(prefix, format.active(buffer))
    end),
    cond = settings.transient(function(buffer)
        return #format.active(buffer) > 0
    end),
    color = settings.transient(function(buffer)
        if not format.enabled(buffer) then
            return hl.hl_fg_color_and_attrs 'DisabledFormattersStatus'
        else
            return hl.hl_fg_color_and_attrs 'ActiveFormattersStatus'
        end
    end),
    on_click = function()
        vim.cmd 'ConformInfo'
    end,
}

--- The section that shows the status of the workspace diagnostics
M.workspace_diagnostics = {
    function()
        local spinner, msg = progress.status 'workspace'
        return spinner and sexify(spinner, msg)
    end,
    cond = function()
        return progress.status 'workspace' ~= nil
    end,
    color = hl.hl_fg_color_and_attrs 'ActiveLSPsStatus',
}

--- The section that shows the status of the LSP
M.lsp = {
    settings.transient(function(buffer)
        local prefix = lsp.progress() or icons.UI.LSP
        return sexify(prefix, lsp.active_names_for_buffer(buffer))
    end),
    cond = settings.transient(function(buffer)
        return lsp.any_active_for_buffer(buffer)
    end),
    color = hl.hl_fg_color_and_attrs 'ActiveLSPsStatus',
    on_click = function()
        vim.cmd 'LspInfo'
    end,
}

local copilot_colors = {
    ['Normal'] = 'CopilotIdle',
    ['InProgress'] = 'CopilotFetching',
    ['Warning'] = 'CopilotWarning',
}

--- The section that shows the status of the copilot
M.copilot = vim.has_plugin 'copilot.lua'
        and {
            settings.transient(function()
                return sexify(icons.Symbols.Copilot, require('copilot.api').status.data.message or '')
            end),
            cond = settings.transient(function(buffer)
                return lsp.is_active_for_buffer(buffer, 'copilot')
            end),
            color = settings.transient(function()
                return hl.hl_fg_color_and_attrs(
                    copilot_colors[require('copilot.api').status.data.status] or copilot_colors['Normal']
                )
            end),
        }
    or nil

--- The section that shows the status of the debugger
M.debugger = {
    function()
        return icons.UI.Debugger .. '  ' .. require('dap').status()
    end,
    cond = function()
        return package.loaded['dap'] and require('dap').status() ~= ''
    end,
    color = hl.hl_fg_color_and_attrs 'Debug',
}

--- The section that shows the status of the git diff
M.diff = {
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
}

--- The section that shows the status of hidden files
M.ignore_hidden_files = {
    function()
        return hl.ignore_hidden_files.active() and icons.UI.IgnoreHidden or icons.UI.ShowHidden
    end,
    color = hl.hl_fg_color_and_attrs 'Comment',
    on_click = function()
        hl.ignore_hidden_files.toggle()
    end,
}

--- The section that shows the status of tmux
M.tmux = {
    function()
        return icons.UI.TMux
    end,
    color = hl.hl_fg_color_and_attrs 'Comment',
    cond = function()
        return require('ui.tmux').socket() ~= nil
    end,
}

--- The section that shows the status of spell checking
M.spell_check = {
    function()
        return icons.UI.SpellCheck
    end,
    color = hl.hl_fg_color_and_attrs 'Comment',
    cond = function()
        return vim.o.spell
    end,
}

--- The section that shows the status of typo checking
M.typo_check = {
    function()
        return icons.UI.TypoCheck
    end,
    cond = settings.transient(function(buffer)
        return lsp.is_active_for_buffer(buffer, 'typos_lsp')
    end),
    color = hl.hl_fg_color_and_attrs 'Comment',
}

--- The section that shows the status of updates
M.lazy_updates = {
    require('lazy.status').updates,
    cond = require('lazy.status').has_updates,
    color = hl.hl_fg_color_and_attrs 'Comment',
    on_click = function()
        vim.cmd 'Lazy'
    end,
}

--- The section that shows the buffer list
M.buffers = {
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
        return delongify(name, 20)
    end,
}

--- The section that shows the tab list
M.tabs = { 'tabs' }

--- The section that shows the progress in file
M.progress = { 'progress' }

--- The section that shows the current location in the file
M.location = { 'location' }

--- The section that shows the mode of vim
M.mode = { 'mode' }

return M
