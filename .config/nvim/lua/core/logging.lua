---@class (strict) core.logging
local M = {}

---Converts a value to a string
---@param value any # any value that will be converted to a string
---@return string|nil # the stringified version of the value
local function stringify(value)
    if value == nil then
        return nil
    elseif type(value) == 'string' then
        return value
    elseif vim.islist(value) then
        return table.concat(value, ', ')
    elseif type(value) == 'table' then
        return vim.inspect(value)
    elseif type(value) == 'function' then
        return stringify(value())
    else
        return tostring(value)
    end
end

---@class core.utils.NotifyOpts # the options to pass to the notification
---@field prefix_icon string|nil # the icon to prefix the message with
---@field suffix_icon string|nil # the icon to suffix the message with
---@field title string|nil # the title of the notification

--- Shows a notification
---@param msg any # the message to show
---@param level integer # the level of the notification
---@param opts core.utils.NotifyOpts|nil # the options to pass to the notification
local function notify(msg, level, opts)
    msg = stringify(msg) or ''

    if opts and opts.prefix_icon then
        msg = opts.prefix_icon .. ' ' .. msg
    end

    if opts and opts.suffix_icon then
        msg = msg .. ' ' .. opts.suffix_icon
    end

    local title = opts and opts.title or 'NeoVim'

    vim.schedule(function()
        vim.notify(msg, level, { title = title })
    end)
end

--- Shows a notification with the INFO type
---@param msg any # the message to show
---@param opts core.utils.NotifyOpts|nil # the options to pass to the notification
function M.info(msg, opts)
    notify(msg, vim.log.levels.INFO, opts)
end

--- Shows a notification with the WARN type
---@param msg any # the message to show
---@param opts core.utils.NotifyOpts|nil # the options to pass to the notification
function M.warn(msg, opts)
    notify(msg, vim.log.levels.WARN, opts)
end

--- Shows a notification with the ERROR type
---@param msg any # the message to show
---@param opts core.utils.NotifyOpts|nil # the options to pass to the notification
function M.error(msg, opts)
    notify(msg, vim.log.levels.ERROR, opts)
end

--- Shows a notification with the HINT type
---@param msg any # the message to show
---@param opts core.utils.NotifyOpts|nil # the options to pass to the notification
function M.hint(msg, opts)
    notify(msg, vim.log.levels.DEBUG, opts)
end

return M
