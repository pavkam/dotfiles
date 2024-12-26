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

---@alias stl_format_item # An item to format for the status line.
---| string # the text to format.
---| number # the number to format.
---| boolean # the boolean to format.
---| icon # the icon to format.
---| symbol # the symbol to format.

local default_status_line_hl = 'StatusLine'

-- Formats a string for status line.
---@param ... stl_format_item # the text items to format.
---@return string # the formatted string.
function M.stl_format(...)
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

    ---@type string|nil
    local last_hl = nil

    for _, part in ipairs(parts) do
        local _, ty = xtype(part)

        if ty == 'table' and part.symbol then
            part = part.symbol
        end

        if ty == 'table' then --[[@cast part symbol]]
            local hl = part.hl or default_status_line_hl
            if hl ~= last_hl then
                result = result .. string.format('%%#%s#%s', hl, part[1])
                last_hl = hl
            else
                result = result .. part[1]
            end
        elseif ty == 'string' then
            result = result .. part
        elseif ty == 'boolean' or ty == 'number' or ty == 'integer' then
            result = result .. tostring(part)
        else
            result = result .. inspect(part, { newline = '', indent = '', separator = ',' })
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

---@class (exact) select_options # The options for the select.
---@field prompt string|nil # the prompt to display.
---@field at_cursor boolean|nil # whether to display the select at the cursor.
---@field separator string|nil # the separator to use between columns.
---@field highlighter nil|fun(row: select_ui_row, row: integer, col: integer): string|nil # the highlighter.
---@field width number|nil # the width of the select.
---@field height number|nil # the height of the select.

---@class (exact) select_column # The column to display.
---@field [1] any # the key of the column.
---@field prio integer|nil # the priority of the column.

--- Select an item from a list of items.
---@generic T: table
---@param items T[] # the list of items to select from.
---@param cols select_column[] # the columns to display.
---@param callback fun(item: T) # the callback to call when an item is selected.
---@param opts select_options|nil # the options for the select.
function M.select(items, cols, callback, opts)
    xassert {
        items = {
            items,
            {
                'list',
                ['>'] = 0,
                ['*'] = 'table',
            },
        },
        callback = { callback, 'callable' },
        cols = {
            cols,
            {
                'list',
                ['>'] = 0,
                ['*'] = 'table', -- TODO: better type checking
            },
        },
        opts = {
            opts,
            {
                'nil',
                {
                    prompt = { 'string', 'nil' },
                    at_cursor = { 'boolean', 'nil' },
                    separator = { 'string', 'nil' },
                    highlighter = { 'callable', 'nil' },
                    width = { 'integer', 'number', 'nil' },
                    height = { 'integer', 'number', 'nil' },
                },
            },
        },
    }

    ---@type string[][]
    local rows = {}
    for _, item in ipairs(items) do
        local row = {}
        for _, conf in ipairs(cols) do
            table.insert(row, item[conf[1]] or '')
        end
        table.insert(rows, row)
    end

    ---@type table<integer, integer>
    local prio_to_index = {}
    for i, conf in ipairs(cols) do
        if conf.prio then
            prio_to_index[i] = conf.prio
        end
    end

    local prios = table.keys(prio_to_index)
    table.sort(prios, function(a, b)
        return a < b
    end)

    local indexes = table.list_map(prios, function(prio)
        return prio_to_index[prio]
    end)

    for _, plugin in ipairs(ide.plugin.select_ui.plugins) do
        local served = plugin.select(rows, {
            prompt = opts and opts.prompt,
            at_cursor = opts and opts.at_cursor,
            separator = opts and opts.separator or (' ' .. require('icons').Symbols.ColumnSeparator .. ' '),
            callback = function(_, row)
                callback(items[row])
            end,
            highlighter = opts and opts.highlighter,
            index_cols = indexes,
            width = opts and opts.width,
            height = opts and opts.height,
        })

        if served then
            return
        end
    end

    M.error 'No select plugin available'
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
