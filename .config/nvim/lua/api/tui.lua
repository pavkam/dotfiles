-- Terminal User Interface API
---@class ide.tui
local M = {}

---@class (exact) vim.NotifyOpts # the options to pass to the notification
---@field prefix_icon string|nil # the icon to prefix the message with
---@field suffix_icon string|nil # the icon to suffix the message with
---@field title string|nil # the title of the notification

--- Shows a notification
---@param msg string # the message to show
---@param level integer # the level of the notification
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
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

--- Shows a notification with the INFO type
---@param msg string # the message to show
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
function M.info(msg, opts)
    notify(msg, vim.log.levels.INFO, opts)
end

--- Shows a notification with the WARN type
---@param msg string # the message to show
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
function M.warn(msg, opts)
    notify(msg, vim.log.levels.WARN, opts)
end

--- Shows a notification with the ERROR type
---@param msg string # the message to show
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
function M.error(msg, opts)
    notify(msg, vim.log.levels.ERROR, opts)
end

--- Shows a notification with the HINT type
---@param msg string # the message to show
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
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

---@class (exact) vim.InvokeOnLineOpts # Options for invoking a function on a specific line
---@field window number|nil # the window to use for the operation, if nil the current window is used.

--- Invokes a function on a specific line without moving the cursor
---@param fn fun()|string # the function to invoke (or the command to run)
---@param line integer # the line to invoke the function on
---@param opts vim.InvokeOnLineOpts|nil # the options for the operation
function M.invoke_on_line(fn, line, opts)
    opts = opts or {}
    opts.window = opts.window or vim.api.nvim_get_current_win()

    assert(type(fn) == 'function' or type(fn) == 'string')
    assert(type(line) == 'number' and line > 0)
    assert(opts.window == nil or type(opts.window) == 'number')

    if not vim.api.nvim_win_is_valid(opts.window) then
        error 'Invalid window'
    end

    local current_pos = vim.api.nvim_win_get_cursor(opts.window)
    vim.api.nvim_win_set_cursor(opts.window, { line, 0 })

    ---@type boolean, any
    local ok, err
    if type(fn) == 'function' then
        ok, err = pcall(fn)
    else
        ok, err = pcall(vim.cmd --[[@as function]], fn)
    end

    vim.api.nvim_win_call(opts.window, function()
        vim.api.nvim_win_set_cursor(opts.window, current_pos)
    end)

    if not ok then
        error(err)
    end
end

return table.freeze(M)
