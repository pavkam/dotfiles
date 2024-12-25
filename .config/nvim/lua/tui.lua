-- Terminal User Interface API
---@class tui
local M = {}

---@class (exact) tui.notify_opts # the options to pass to the notification.
---@field prefix_icon string|nil # the icon to prefix the message with.
---@field suffix_icon string|nil # the icon to suffix the message with.
---@field title string|nil # the title of the notification.

--- Shows a notification.
---@param msg string # the message to show.
---@param level integer # the level of the notification.
---@param opts tui.notify_opts|nil # the options to pass to the notification.
local function notify(msg, level, opts)
    if opts and opts.prefix_icon then
        msg = opts.prefix_icon .. ' ' .. msg
    end

    if opts and opts.suffix_icon then
        msg = msg .. ' ' .. opts.suffix_icon
    end

    local title = opts and opts.title or 'NeoVim'

    if vim.v.exiting ~= vim.NIL or vim.v.dying > 0 then
        if level == vim.log.levels.ERROR then
            vim.api.nvim_err_writeln(string.format('[%s] %s', title, msg))
        else
            vim.api.nvim_out_write(string.format('[%s] %s\n', title, msg))
        end

        return
    end

    if vim.in_fast_event() then
        vim.notify(msg, level, { title = title })
        return
    end

    vim.schedule(function()
        vim.notify(msg, level, { title = title })
    end)
end

--- Shows a notification with the INFO type.
---@param msg string # the message to show.
---@param opts tui.notify_opts|nil # the options to pass to the notification.
function M.info(msg, opts)
    notify(msg, vim.log.levels.INFO, opts)
end

--- Shows a notification with the WARN type.
---@param msg string # the message to show.
---@param opts tui.notify_opts|nil # the options to pass to the notification.
function M.warn(msg, opts)
    notify(msg, vim.log.levels.WARN, opts)
end

--- Shows a notification with the ERROR type.
---@param msg string # the message to show.
---@param opts tui.notify_opts|nil # the options to pass to the notification.
function M.error(msg, opts)
    notify(msg, vim.log.levels.ERROR, opts)
end

--- Shows a notification with the HINT type.
---@param msg string # the message to show.
---@param opts tui.notify_opts|nil # the options to pass to the notification.
function M.hint(msg, opts)
    notify(msg, vim.log.levels.DEBUG, opts)
end

--- Redraws the UI.
function M.redraw()
    vim.cmd 'resize'
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. vim.fn.tabpagenr())
    vim.cmd 'redraw!'
end

---@alias bar_format_text # A string that can be formatted with `bar_format`.
---| string # the text to format.
---| { [1]:string, hl: string } # the text to format with a highlight group.

local default_status_line_hl = 'StatusLine'

-- Formats a string for status line.
---@param ... bar_format_text # the text to format.
---@return string # the formatted string.
function M.format_for_status_line(...)
    local parts = { ... }

    xassert {
        parts = {
            parts,
            {
                'list',
                ['*'] = {
                    'string',
                    'table', -- TODO: better type checking
                },
            },
        },
    }

    local result = ''
    local last_hl = default_status_line_hl
    for _, part in ipairs(parts) do
        local _, ty = xtype(part)
        if ty == 'table' then
            if part.hl and part.hl ~= last_hl then
                result = result .. string.format('%%#%s#%s', part.hl, part[1])
                last_hl = part.hl
            else
                result = result .. part[1]
            end
        elseif ty == 'string' then
            if last_hl ~= default_status_line_hl then
                result = result .. string.format('%%#%s#%s', last_hl, part)
                last_hl = default_status_line_hl
            else
                result = result .. part
            end
        end
    end

    return result
end

local function extract_shortcut(label)
    xassert {
        label = { label, { 'string', ['>'] = 0 } },
    }

    local shortcuts = {}
    local i = 1
    local amp_len = 0

    while i <= #label do
        local ch = label:sub(i, i)
        i = i + 1

        if ch == '&' and amp_len < 3 then
            amp_len = amp_len + 1
        elseif amp_len % 2 == 1 then
            table.insert(shortcuts, ch)
            amp_len = 0
        end
    end

    return #shortcuts == 1 and shortcuts[1] or nil
end

---@class (exact) ask_choice # The choice to present to the user.
---@field [1] string # the label of the choice.
---@field [2] any|nil # the value of the choice.

--- Asks the user a question with a list of choices.
---@param question string # the question to ask.
---@param choices ask_choice[] # the list of choices to present to the user.
---@return any|nil # the value of the choice the user selected.
function M.ask(question, choices)
    xassert {
        question = { question, { 'string', ['>'] = 0 } },
        choices = { choices, { 'list', ['>'] = 0 } },
    }

    local labels = table.list_map(choices, function(c)
        return c[1]
    end)

    xassert {
        choices = {
            table.list_map(labels, extract_shortcut),
            {
                'list',
                ['>'] = #choices - 1,
                ['<'] = #choices + 1,
            },
        },
    }

    local choice = vim.fn.confirm(question, table.concat(labels, '\n'))

    if choice == 0 then
        return nil
    end

    return choices[choice][2] or choices[choice][1]
end

--- Asks the user a question with a list of choices.
---@param question string # the question to ask.
---@return boolean|nil # the value of the choice the user selected.
function M.confirm(question)
    xassert {
        question = { question, { 'string', ['>'] = 0 } },
    }

    return M.ask(question, {
        { '&Yes', true },
        { '&No', false },
        { '&Cancel', nil },
    })
end

local ignore_hidden_files_option = ide.config.register_toggle('ignore_hidden_files', function(enabled)
    if package.loaded['neo-tree'] then
        -- Update neo-tree state
        local mgr = require 'neo-tree.sources.manager'
        mgr.get_state('filesystem').filtered_items.visible = not enabled
    end
end, { icon = require('icons').UI.ShowHidden, desc = 'Ignore hidden files', scope = 'global' })

M.ignore_hidden_files = {
    --- Returns whether hidden files are ignored or not
    ---@return boolean # true if hidden files are ignored, false otherwise
    active = ignore_hidden_files_option.get,
    --- Toggles ignoring of hidden files on or off
    ---@param value boolean|nil # if nil, it will toggle the current value, otherwise it will set the value
    toggle = function(value)
        ignore_hidden_files_option.set(value)
    end,
}

return table.freeze(M)
