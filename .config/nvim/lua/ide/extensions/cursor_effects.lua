-- Cursor effects extension: visual feedback and lifecycle behaviors.
-- Cursorline tracking, yank highlight, external change detection, resize, macro tracking.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local CursorEffects = Class('CursorEffects', Extension)

function CursorEffects:init()
    Extension.init(self, 'CursorEffects')
end

function CursorEffects:on_register(ctx)
    -- Show cursorline only in the active window with a normal buffer
    ctx:hook({ 'InsertLeave', 'WinEnter' }, function(evt)
        if Buffer.is_valid(evt.buf) and Buffer.get(evt.buf):is_normal() then
            Window.current():set_option('cursorline', true)
        end
    end, { desc = 'Show cursorline on focus' })

    ctx:hook({ 'InsertEnter', 'WinLeave' }, function()
        Window.current():set_option('cursorline', false)
    end, { desc = 'Hide cursorline on leave' })

    -- Brief highlight on yank
    ctx:hook('TextYankPost', function()
        IDE.ui:highlight_yank()
    end, { desc = 'Highlight yanked text' })

    -- Check for external changes on focus
    ctx:hook({ 'FocusGained', 'TermClose', 'TermLeave' }, function()
        local buf = IDE.buffers:current()
        if buf:is_valid() and buf:is_normal() then
            IDE.ui:checktime()
        end
    end, { desc = 'Check external changes on focus' })

    ctx:hook({ 'CursorHold', 'CursorHoldI' }, function(evt)
        if Buffer.is_valid(evt.buf) and Buffer.get(evt.buf):is_normal() then
            IDE.ui:checktime()
        end
    end, { desc = 'Check external changes on idle' })

    -- Equalize splits on resize
    ctx:hook('VimResized', function()
        ctx:schedule(function() IDE.ui:redraw() end)
    end, { desc = 'Equalize splits on resize' })

    -- Refresh statusline on LSP/buffer events
    ctx:hook({ 'LspDetach', 'LspAttach', 'BufWritePost', 'BufEnter', 'VimResized' }, function()
        ctx:schedule(function() IDE.ui:refresh_status() end)
    end, { desc = 'Refresh statusline on events' })

    -- Macro recording notifications (user-friendly, no register names)
    ctx:hook('RecordingEnter', function()
        IDE.ui:info(' Recording actions...')
    end, { desc = 'Macro start notification' })

    ctx:hook('RecordingLeave', function()
        IDE.ui:info(' Recording saved')
    end, { desc = 'Macro stop notification' })
end

return CursorEffects
