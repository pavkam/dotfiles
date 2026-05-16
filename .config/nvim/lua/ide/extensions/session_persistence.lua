-- Session persistence extension: auto-save/restore sessions.
-- Replaces legacy sessions.lua autocommands.
--
-- Features:
--   - Restore session on startup with notification
--   - Save session on exit
--   - Swap sessions on focus change (project/branch switch)
--   - Periodic auto-save every 5 minutes
--   - Quickfix list and cursor position persistence (via SessionManager)

local Extension = require 'ide.Extension'
local Timer = require 'ide.Timer'

local SessionPersistence = Class('SessionPersistence', Extension)

function SessionPersistence:init()
    Extension.init(self, 'SessionPersistence')
end

function SessionPersistence:on_register(ctx)
    if not IDE.session:is_enabled() then return end

    -- Restore session on startup
    ctx:hook('User', function()
        local name = IDE.session:current()
        if name then
            local buf_count = IDE.session:restore(name)
            if buf_count > 0 then
                IDE.ui:info('Session restored: ' .. buf_count .. ' buffers')
            end
        end
    end, { pattern = 'LazyVimStarted', once = true, desc = 'Restore session on startup' })

    -- Save session before quitting
    ctx:hook('VimLeavePre', function()
        local name = IDE.session:current()
        if name then
            IDE.session:save(name)
        end
    end, { desc = 'Save session on exit' })

    -- Swap sessions on focus change (project switch)
    local current_name = nil
    ctx:hook({ 'FocusGained', 'TermClose', 'TermLeave' }, function()
        local new_name = IDE.session:current()
        if new_name ~= current_name then
            if current_name then IDE.session:save(current_name) end
            if new_name then
                local buf_count = IDE.session:restore(new_name)
                if buf_count > 0 then
                    IDE.ui:info('Session restored: ' .. buf_count .. ' buffers')
                end
            end
            current_name = new_name
        end
    end, { desc = 'Swap sessions on focus change' })

    -- Periodic auto-save every 5 minutes
    local save_timer = Timer.interval(300000, function()
        local name = IDE.session:current()
        if name then
            pcall(function() IDE.session:save(name) end)
        end
    end, 'session-autosave')
    -- Keep reference so it doesn't get GC'd
    self._save_timer = save_timer
end

return SessionPersistence
