local icons = require 'ui.icons'

require 'api.vim.fn'
require 'api.vim.fs'
require 'api.vim.filetype'

--- Converts a value to a list
---@param value any # any value that will be converted to a list
---@return any[] # the listified version of the value
function vim.to_list(value)
    if value == nil then
        return {}
    elseif vim.islist(value) then
        return value
    elseif type(value) == 'table' then
        local list = {}
        for _, item in ipairs(value) do
            table.insert(list, item)
        end

        return list
    else
        return { value }
    end
end

--- Returns a new list that contains only unique values
---@param list any[] # the list to make unique
---@param key_fn (fun(value: any): any)|nil # the function to get the key from the value
---@return any[] # the list with unique values
function vim.list_uniq(list, key_fn)
    assert(vim.islist(list))
    assert(key_fn == nil or type(key_fn) == 'function')

    local seen = {}
    local result = {}

    for _, item in ipairs(list) do
        local key = key_fn and key_fn(item) or item
        if not seen[key] then
            table.insert(result, item)
            seen[key] = true
        end
    end

    return result
end

--- Inflates a list to a table
---@generic T: table
---@param list T[] # the list to inflate
---@param key_fn fun(value: T): string # the function to get the key from the value
---@return table<string, T> # the inflated table
function vim.inflate_list(key_fn, list)
    assert(vim.islist(list) and type(key_fn) == 'function')

    ---@type table<string, table>
    local result = {}

    for _, value in ipairs(list) do
        local key = key_fn(value)
        result[key] = value
    end

    return result
end

--- Merges multiple tables into one
---@vararg table|nil # the tables to merge
---@return table # the merged table
function vim.tbl_merge(...)
    local all = {}

    for _, a in ipairs { ... } do
        if a then
            table.insert(all, a)
        end
    end

    if #all == 0 then
        return {}
    elseif #all == 1 then
        return all[1]
    else
        return vim.tbl_deep_extend('force', unpack(all))
    end
end

--- Checks if a plugin is available
---@param name string # the name of the plugin
---@return boolean # true if the plugin is available, false otherwise
function vim.has_plugin(name)
    assert(type(name) == 'string' and name ~= '')

    if package.loaded['lazy'] then
        return require('lazy.core.config').spec.plugins[name] ~= nil
    end

    return false
end

---Converts a value to a string
---@param value any # any value that will be converted to a string
---@return string|nil # the stringified version of the value
function vim.stringify(value)
    if value == nil then
        return nil
    elseif type(value) == 'string' then
        return value
    elseif vim.islist(value) then
        return table.concat(value, ', ')
    elseif type(value) == 'table' then
        return vim.inspect(value)
    elseif type(value) == 'function' then
        return vim.stringify(value())
    else
        return tostring(value)
    end
end

---@class (exact) vim.NotifyOpts # the options to pass to the notification
---@field prefix_icon string|nil # the icon to prefix the message with
---@field suffix_icon string|nil # the icon to suffix the message with
---@field title string|nil # the title of the notification

--- Shows a notification
---@param msg any # the message to show
---@param level integer # the level of the notification
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
local function notify(msg, level, opts)
    msg = vim.stringify(msg) or ''

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
---@param msg any # the message to show
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
function vim.info(msg, opts)
    notify(msg, vim.log.levels.INFO, opts)
end

--- Shows a notification with the WARN type
---@param msg any # the message to show
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
function vim.warn(msg, opts)
    notify(msg, vim.log.levels.WARN, opts)
end

--- Shows a notification with the ERROR type
---@param msg any # the message to show
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
function vim.error(msg, opts)
    notify(msg, vim.log.levels.ERROR, opts)
end

--- Shows a notification with the HINT type
---@param msg any # the message to show
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
function vim.hint(msg, opts)
    notify(msg, vim.log.levels.DEBUG, opts)
end

---@alias vim.DebouncedFn fun(buffer: integer, ...) # A debounced function

--- Defers a function call for buffer in LIFO mode. If the function is called again before the timeout, the
--- timer is reset.
---@param fn vim.DebouncedFn # the function to call
---@param timeout integer # the timeout in milliseconds
---@return vim.DebouncedFn # the debounced function
function vim.debounce_fn(fn, timeout)
    ---@type table<integer, uv_timer_t>
    local timers = {}

    ---@type vim.DebouncedFn
    return function(buffer, ...)
        buffer = buffer or vim.api.nvim_get_current_buf()

        assert(vim.api.nvim_buf_is_valid(buffer))

        local timer = timers[buffer]
        if not timer then
            timer = vim.uv.new_timer()
            timers[buffer] = timer
        else
            timer:stop()
        end

        local args = { ... }
        assert(timer:start(
            timeout,
            0,
            vim.schedule_wrap(function()
                timer:stop()

                if vim.api.nvim_buf_is_valid(buffer) then
                    vim.api.nvim_buf_call(buffer, function()
                        fn(buffer, unpack(args))
                    end)
                end
            end)
        ))
    end
end

---@alias vim.PolledFn fun(...): boolean # A polled function

--- Polls a function until it returns false
---@param fn vim.PolledFn # the function to call
---@param timeout integer # the timeout in milliseconds
function vim.poll_fn(fn, timeout, ...)
    local timer = vim.uv.new_timer()

    local args = { ... }
    assert(timer:start(
        timeout,
        timeout,
        vim.schedule_wrap(function()
            if not fn(unpack(args)) then
                timer:stop()
            end
        end)
    ))
end

--- Refreshes the UI
function vim.refresh_ui()
    vim.cmd.resize()

    local current_tab = vim.fn.tabpagenr()

    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
    vim.cmd 'redraw!'
end

---@class (exact) vim.AbbreviateOpts
---@field max number|nil # The maximum length of the string (default: 40)
---@field ellipsis string|nil # The ellipsis to append to the cut-off string (default: '...')

--- Abbreviate a string with an optional maximum length and ellipsis
---@param str string # The string to cut off
---@param opts vim.AbbreviateOpts|nil # The options for the abbreviation
---(if not provided, the default ellipsis is '...')
---@return string # The cut-off string
function vim.fn.abbreviate(str, opts)
    if not str or str == '' then
        return ''
    end

    assert(type(str) == 'string')

    opts = opts or {}

    local max = opts.max or 40
    local ellipsis = opts.ellipsis or icons.TUI.Ellipsis

    if #str > max then
        if opts.ellipsis then
            return str:sub(1, max - #ellipsis) .. ellipsis
        else
            return str:sub(1, max)
        end
    end

    return str
end
