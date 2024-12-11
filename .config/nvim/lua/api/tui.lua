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

return table.freeze(M)
