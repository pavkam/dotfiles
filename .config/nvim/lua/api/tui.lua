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

return table.freeze(M)
