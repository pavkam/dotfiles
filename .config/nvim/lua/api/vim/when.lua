---@class vim.when
vim.when = {}

---@type table<string, integer>
local group_registry = {}

--- Creates an auto command that triggers on a given list of events
---@generic T # the return type of the callback
---@param events string|string[] # the list of events to trigger on
---@param callback fun(): T # the callback to call when the event is triggered
---@param target table|string|number|nil # the target to trigger on
---@return fun(): T # the function that can be called to get the result of the callback
local function attach(events, callback, target)
    vim.assert.callable(callback)

    events = vim.assert.list(vim.islist(events --[[@as table]]) and events or {
        events --[[@as string ]],
    } --[[@as string[] ]]) --[[@as string[] ]]

    if type(target) == 'number' then
        target = vim.assert.buffer_id(target)
    elseif type(target) == 'string' then
        target = vim.assert.string(target, { empty = false })
    elseif target ~= nil then
        vim.assert.list(target, { types = { 'string', 'number' } })
    end

    -- create/update group
    local group_name = get_trace_back(4)[1].file
    local group = group_registry[group_name]
    if not group then
        group = group or vim.api.nvim_create_augroup(group_name, { clear = true })
        group_registry[group_name] = group
    end

    local reg_trace_back = get_formatted_trace_back(4)
    local result

    ---@type vim.api.keyset.create_autocmd
    local opts = {
        callback = function(evt)
            local ok, err_or_res = pcall(callback, evt, group)
            if not ok then
                vim.error(
                    string.format(
                        'Error in auto command `%s`: `%s`\n\n%s',
                        vim.inspect(events),
                        err_or_res,
                        reg_trace_back
                    )
                )
            else
                result = err_or_res
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

    return function()
        return result
    end
end

--- Triggers when vim is fully ready.
---@generic T # the return type of the callback.
---@param callback fun(evt: any, group: number): T # the callback to call when vim is ready.
---@return fun(): T # the function that can be called to get the result of the callback.
function vim.when.ready(callback)
    return attach('User', callback, 'LazyVimStarted')
end

--- Triggers when vim is about to quit.
---@generic T # the return type of the callback.
---@param callback fun(evt: any, group: number): T # the callback to call when vim is about to quit.
---@return fun(): T # the function that can be called to get the result of the callback.
function vim.when.quitting(callback)
    return attach('VimLeavePre', callback)
end

--- Triggers when vim receives focus.
---@generic T # the return type of the callback.
---@param callback fun(evt: any, group: number): T # the callback to call when vim regained focus.
---@return fun(): T # the function that can be called to get the result of the callback.
function vim.when.focus_gained(callback)
    return attach({ 'FocusGained', 'TermClose', 'TermLeave', 'DirChanged' }, callback)
end
