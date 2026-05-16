-- File palette extension: quick file switcher using owned SelectPicker.
-- Shows open buffers + recent files in a TurboVision dialog.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local FilePalette = Class('FilePalette', Extension)

function FilePalette:init()
    Extension.init(self, 'FilePalette')
end

function FilePalette:show()
    local SelectPicker = require 'ide.toolkit.SelectPicker'
    local items = {}
    local seen = {}

    -- Open buffers first
    local bufs = IDE.buffers:listed()
    local cur_id = Buffer.current():id()
    for _, buf in ipairs(bufs) do
        if buf:is_valid() and buf:path() then
            local path = buf:path()
            local rel = IDE.fs:display_path(path)
            local modified = buf:is_modified() and ' [+]' or ''
            local marker = buf:id() == cur_id and '● ' or '  '
            items[#items + 1] = {
                text = marker .. rel .. modified,
                value = path,
            }
            seen[path] = true
        end
    end

    -- Recent files
    local oldfiles = vim.v.oldfiles or {}
    for _, path in ipairs(oldfiles) do
        if not seen[path] and IDE.fs:is_file(path) then
            local rel = IDE.fs:display_path(path)
            items[#items + 1] = { text = '  ' .. rel, value = path }
            seen[path] = true
            if #items >= 30 then break end
        end
    end

    SelectPicker({
        title = 'Switch File',
        items = items,
        on_select = function(item)
            require('ide.Buffer').open(item.value)
        end,
    }):show()
end

function FilePalette:on_register(ctx)
    local ext = self
    ctx:command('Files', function() ext:show() end, { desc = 'Show file palette' })
    ctx:keymap('n', '<F3>', function() ext:show() end, { desc = 'File palette' })
    ctx:keymap('n', '<leader>b', function() ext:show() end, { desc = 'File palette' })
end

return FilePalette
