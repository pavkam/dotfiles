local process = require 'api.process'
local assert = require 'api.assert'

-- HACK: This is a workaround for the fact that lua_ls doesn't support generic classes.
-- luacheck: push ignore 631

---@class (exact) api.events.Slot<TIn, TOut>: { ["continue"]: (fun(continuation: fun(args: TIn, slot: api.events.Slot<TIn, TOut>): TOut): api.events.Slot<TIn, TOut>), ["trigger"]: fun(args: TIn) } # A slot object.

-- luacheck: pop

---@alias api.events.RawSlot # A raw slot object.
---| api.events.Slot<any, any>

-- Create a new raw slot (internal).
---@param handler (fun(args: any, slot: api.events.RawSlot): any) | nil # the handler of the slot.
---@returns api.events.RawSlot # the slot object.
local function new_slot(handler)
    ---@type table<api.events.RawSlot, boolean>
    local subscribers = {}

    local obj = {}

    obj.continue = function(continuation)
        local follower = new_slot(continuation)
        subscribers[follower] = true

        return follower
    end

    obj.trigger = function(args)
        args = handler and handler(args, obj) or args

        for subscriber in pairs(subscribers) do
            subscriber.trigger(args)
        end
    end

    ---@type api.events.RawSlot
    return obj
end

---@class (exact) api.events.AutoCommandOpts # The options for the auto command.
---@field buffer integer|nil # the buffer to target (or `nil` for all buffers).
---@field description string # the description of the auto command.
---@field group string|nil # the group of the auto command.
---@field patterns string[]|nil # the pattern to target (or `nil` for all patterns).

---@class (exact) vim.AutoCommandData # The event data received by the auto command.
---@field id integer # the id of the auto command.
---@field event string # the event that was triggered.
---@field buf integer|nil # the buffer the event was triggered on (or `nil` of no buffer).
---@field group integer|nil # the group of the auto command.
---@field match string|nil # the match of the auto command.

---@param events string[] # the list of events to trigger on.
---@param opts api.events.AutoCommandOpts # the options for the auto command.
---@returns api.events.Slot<api.events.AutoCommandEventData, any> # the slot object.
local function create_auto_command_slot(events, opts)
    assert {
        events = { events, { ['*'] = 'string' } },
        opts = {
            opts,
            {
                buffer = { 'number', 'nil' },
                description = 'string',
                group = { 'string', 'nil' },
                patterns = { 'nil', { ['*'] = 'string' } },
            },
        },
    }

    local slot = new_slot()
    local slot_trigger = slot.trigger

    local reg_trace_back = process.get_formatted_trace_back(4)
    local defacto_group = opts.group or 'global_events'
    local auto_group_id = vim.api.nvim_create_augroup(defacto_group, { clear = opts.group ~= nil })

    ---@type vim.api.keyset.create_autocmd
    local auto_command_opts = {
        callback = function(args)
            local ok, err = pcall(slot_trigger, args)

            if not ok then
                local formatted = table.concat(
                    #events == 1 and events[1] == 'User' and opts.patterns and #opts.patterns > 0 and opts.patterns
                        or events,
                    ', '
                )

                vim.error(
                    string.format(
                        'Error in auto command `%s`: %s\nPayload:\n%s\nRegistered at:\n%s',
                        formatted,
                        err,
                        vim.inspect(args),
                        reg_trace_back
                    )
                )
            end
        end,
        group = auto_group_id,
        pattern = opts.patterns,
        desc = opts.description,
        nested = false,
    }

    -- create auto command
    vim.api.nvim_create_autocmd(events, auto_command_opts)

    slot.trigger = function(args)
        vim.api.nvim_exec_autocmds(events, { pattern = opts.patterns, modeline = false, data = args })
    end

    ---@type api.events.Slot<vim.AutoCommandData, any>
    return slot
end

---@class (exact) api.events.AutoCommandEventData # The event data received by the auto command.
---@field id integer # the id of the auto command.
---@field event string # the event that was triggered.
---@field is_custom boolean # whether the event is a custom event.
---@field is_system boolean # whether the event is a system event.
---@field buffer integer|nil # the buffer the event was triggered on (or `nil` of no buffer).
---@field group string|nil # the group of the auto command.
---@field original table # the original event data.

---@param args vim.AutoCommandData
local function buffer_continuation(args)
    local buffer = vim.api.nvim_buf_is_valid(evt.buf) and evt.buf or nil

    ---@type api.events.AutoCommandEventData
    local data = {
        id = evt.id,
        buffer = buffer,
        event = evt.event == 'User' and evt.match or evt.event,
        group = defacto_group,
        is_custom = evt.event == 'User',
        is_system = evt.event ~= 'User',
        original = evt,
    }
end

---@class api.events
local M = {}

---@type api.events.Slot<string, string>
M.ready = create_auto_command_slot({ 'User' }, {
    description = 'Triggers when vim is fully ready.',
    patterns = { 'LazyVimStarted' },
}).continue(function()
    return {}
end)

M.before_quitting = create_auto_command_slot({ 'VimLeavePre' }, {
    description = 'Triggers when vim is ready to quit.',
}).continue(function()
    return {
        exit_code = vim.v.exiting == vim.v.null and 0 or vim.v.exiting --[[@as integer]],
        dying = vim.v.dying > 0,
    }
end)

M.focus_gained = create_auto_command_slot({ 'FocusGained', 'TermClose', 'TermLeave', 'DirChanged' }, {
    description = 'Triggers when vim receives focus.',
})

M.before_colors_change = create_auto_command_slot({ 'ColorSchemePre', 'ColorScheme' }, {
    description = 'Triggers before the colors change.',
}).continue(function(data)
    return {
        color_scheme = data.match,
    }
end)

M.after_colors_change = create_auto_command_slot({ 'ColorScheme' }, {
    description = 'Triggers after the colors change.',
})

return M
