-- Mark signs extension: sign column indicators for marks, enhanced m keymap.
-- Replaces legacy marks.lua.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local MarkSigns = Class('MarkSigns', Extension)

local ns = nil

function MarkSigns:init()
    Extension.init(self, 'MarkSigns')
end

function MarkSigns:_update_signs(bufnr)
    bufnr = bufnr or Buffer.current():id()
    if not Buffer.is_valid(bufnr) then return end
    if not ns then ns = Buffer.create_namespace('ide_mark_signs') end

    local buf = Buffer.get(bufnr)
    buf:clear_extmarks(ns)

    local marks = IDE.marks:list(bufnr)
    for _, m in ipairs(marks) do
        if m.pos.row > 0 then
            pcall(buf.set_extmark, buf, ns, m.pos.row - 1, 0, {
                sign_text = m.mark,
                sign_hl_group = 'MarkSign',
                priority = 10,
            })
        end
    end

    IDE.ui:refresh_status()
end

function MarkSigns:on_register(ctx)
    local ext = self

    IDE.theme:link('MarkSign', 'DiagnosticWarn')

    -- Enhanced m keymap: set mark or m- to delete marks at cursor
    ctx:keymap('n', 'm', function()
        local key = IDE.ui:getchar()
        if not key then return end

        local pos = Window.current():cursor()

        if key == '-' then
            local marks = IDE.marks:list()
            for _, m in ipairs(marks) do
                if m.pos.row == pos.row then
                    IDE.marks:delete(m.mark)
                    IDE.ui:info(string.format('Removed mark `%s`', m.mark))
                end
            end
            ext:_update_signs()
        elseif key:match('^[a-zA-Z]$') then
            IDE.marks:set(key)
            IDE.ui:info(string.format('Set mark `%s` at %d:%d', key, pos.row, pos.col))
            ext:_update_signs()
        end
    end, { desc = 'Set/delete mark' })

    -- Refresh signs on buffer enter
    ctx:hook('BufEnter', function(evt)
        if not Buffer.is_valid(evt.buf) or not Buffer.get(evt.buf):is_normal() then return end
        ctx:schedule(function() ext:_update_signs(evt.buf) end)
    end, { desc = 'Refresh mark signs' })

    -- Refresh after delmarks command
    ctx:hook('CmdlineLeave', function(evt)
        ctx:schedule(function()
            if IDE.ui:get_register(':'):match('^delm') then
                ext:_update_signs(evt.buf)
            end
        end)
    end, { pattern = ':', desc = 'Refresh after delmarks' })
end

return MarkSigns
