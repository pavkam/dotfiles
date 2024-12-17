---@class core.events
local M = {}

---@type table<string, integer>
local group_registry = {}

--- Creates an auto command that triggers on a given list of events
---@param events string|string[] # the list of events to trigger on
---@param callback function # the callback to call when the event is triggered
---@param target table|string|number|nil # the target to trigger on
---@return number # the group id of the created group
local function on_event(events, callback, target)
    assert(type(callback) == 'function')

    events = table.to_list(events)
    target = table.to_list(target)

    -- create/update group
    local group_name = require('api.process').get_trace_back(3)[1].file
    local group = group_registry[group_name]
    if not group then
        group = group or vim.api.nvim_create_augroup(group_name, { clear = true })
        group_registry[group_name] = group
    end

    local reg_trace_back = require('api.process').get_formatted_trace_back(4)
    local opts = {
        callback = function(evt)
            local ok, err = pcall(callback, evt, group)
            if not ok then
                require('api.tui').error(
                    string.format('Error in auto command `%s`: `%s`\n\n%s', vim.inspect(events), err, reg_trace_back)
                )
            end
        end,
        group = group,
    }

    -- decide on the target
    if type(target) == 'number' then
        opts.buffer = target
    elseif target then
        opts.pattern = target
    end

    -- create auto command
    vim.api.nvim_create_autocmd(events, opts)

    return group
end

--- Creates an auto command that triggers on a given list of events
---@param events string|string[] # the list of events to trigger on
---@param callback function # the callback to call when the event is triggered
---@param target table|string|number|nil # the target to trigger on
---@return number # the group id of the created group
function M.on_event(events, callback, target)
    return on_event(events, callback, target)
end

--- Creates an auto command that triggers on a given list of user events
---@param events string|table # the list of events to trigger on
---@param callback function # the callback to call when the event is triggered
---@return number # the group id of the created group
function M.on_user_event(events, callback)
    events = table.to_list(events)
    return on_event('User', function(evt)
        callback(evt.match, evt)
    end, events)
end

--- Creates an auto command that triggers on focus gained
---@param callback function # the callback to call when the event is triggered
function M.on_focus_gained(callback)
    assert(type(callback) == 'function')

    on_event({ 'FocusGained', 'TermClose', 'TermLeave' }, callback)
    on_event({ 'DirChanged' }, callback, 'global')
end

--- Creates an auto command that triggers on global status update event
---@param callback function # the callback to call when the event is triggered
---@return number # the group id of the created group
function M.on_status_update_event(callback)
    return on_event('User', callback, 'StatusUpdate')
end

--- Trigger a user event
---@param event string # the name of the event to trigger
---@param data any # the data to pass to the event
function M.trigger_user_event(event, data)
    vim.api.nvim_exec_autocmds('User', { pattern = event, modeline = false, data = data })
end

--- Trigger a status update event
function M.trigger_status_update_event()
    M.trigger_user_event 'StatusUpdate'
end

return M
