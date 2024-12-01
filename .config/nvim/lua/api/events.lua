local process = require 'api.process'
local assert = require 'api.assert'

---@class api.events.Slot # The slot object.
---@field continue fun(follow_up: fun(args: any)): api.events.Slot # adds a follow-up to the slot.
---@field trigger fun(args: any): any # triggers the slot with the given data.
---@field source any|nil # the source of the slot.

---@param handler fun(args: any)|nil # the handler to call when the slot is triggered.
---@returns api.events.Slot # the slot object.
local function new_slot(handler)
    ---@type { trigger: fun(args: any) }[]
    local subscribers = {}

    ---@type api.events.Slot
    local obj = {
        continue = function(follow_up)
            local follower = new_slot(follow_up)
            table.insert(subscribers, follower)

            return follower
        end,

        trigger = function(args)
            local result = handler and handler(args)
            for _, subscriber in ipairs(subscribers) do
                subscriber.trigger(args)
            end

            return result
        end,
    }

    return obj
end

---@class (exact) api.events.AutoCommandOpts # The options for the auto command.
---@field buffer integer|nil # the buffer to target (or `nil` for all buffers).
---@field description string # the description of the auto command.
---@field group string|nil # the group of the auto command.
---@field patterns string[]|nil # the pattern to target (or `nil` for all patterns).

---@class (exact) api.events.AutoCommandEventData # The event data received by the auto command.
---@field id integer # the id of the auto command.
---@field event string # the event that was triggered.
---@field is_custom boolean # whether the event is a custom event.
---@field is_system boolean # whether the event is a system event.
---@field buffer integer|nil # the buffer the event was triggered on (or `nil` of no buffer).
---@field group string|nil # the group of the auto command.
---@field original table # the original event data.

---@class api.events.AutoCommandSlot # The auto command slot.
---@field continue fun(follow_up: fun(args: api.events.AutoCommandEventData)) # continues the slot with a follow-up.
---@field trigger fun(args: any|nil) # triggers the auto command with the given data.

---@param events string[] # the list of events to trigger on.
---@param opts api.events.AutoCommandOpts # the options for the auto command.
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
    ---@type { trigger: fun(args: any) }[]

    local slot = new_slot()
    local slot_trigger = slot.trigger

    local reg_trace_back = process.get_formatted_trace_back(4)
    local defacto_group = opts.group or 'global_events'
    local auto_group_id = vim.api.nvim_create_augroup(defacto_group, { clear = opts.group ~= nil })

    ---@type vim.api.keyset.create_autocmd
    local auto_command_opts = {
        callback = function(evt)
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

            local ok, err = pcall(slot_trigger, data)

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
                        vim.inspect(data),
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

    slot.source = {
        auto_command_id = vim.api.nvim_create_autocmd(events, auto_command_opts),
        group = opts.group,
    }

    ---@cast slot api.events.AutoCommandSlot
    slot.trigger = function(args)
        vim.api.nvim_exec_autocmds(events, { pattern = opts.patterns, modeline = false, data = args })
    end

    return slot
end

---@class api.events
local M = {}

M.ready = create_auto_command_slot({ 'User' }, {
    description = 'Triggers when vim is fully ready.',
    patterns = { 'LazyVimStarted' },
})

M.before_quitting = create_auto_command_slot({ 'VimLeavePre' }, {
    description = 'Triggers when vim is ready to quit.',
})

M.focus_gained = create_auto_command_slot({ 'FocusGained', 'TermClose', 'TermLeave', 'DirChanged' }, {
    description = 'Triggers when vim receives focus.',
})

M.before_colors_change = create_auto_command_slot({ 'ColorSchemePre', 'ColorScheme' }, {
    description = 'Triggers before the colors change.',
}).continue(function(data)
    dbg(data)
end)

M.after_colors_change = create_auto_command_slot({ 'ColorScheme' }, {
    description = 'Triggers after the colors change.',
})

return M
