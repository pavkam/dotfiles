-- Buffer Picker Extension: interactive buffer selection.
-- Provides :IDEBuffers command with TurboVision-style formatting.

local Extension = require 'ide.Extension'

local BufferPicker = Class('BufferPicker', Extension)

function BufferPicker:init()
    Extension.init(self, 'BufferPicker')
end

function BufferPicker:on_register(ctx)
    ctx:command('IDEBuffers', function()
        local items = {}
        local current_id = IDE.buffers:current():id()
        for buf in IDE.buffers:iter() do
            if buf:is_valid() then
                local name = buf:name() or '[No Name]'
                local icon = IDE.icons and IDE.icons:for_file(name) or ''
                local modified = buf:is_modified() and ' [+]' or ''
                local marker = buf:id() == current_id and '●' or ' '
                items[#items + 1] = {
                    text = string.format('%s  %s  %s%s', marker, icon, name, modified),
                    buf = buf,
                    is_current = buf:id() == current_id,
                    is_modified = buf:is_modified(),
                }
            end
        end
        IDE.toolkit.Picker({
            title = ' Buffers',
            items = items,
            format = function(item) return item.text end,
            on_select = function(item)
                IDE.buffers:switch_to(item.buf)
            end,
        }):show()
    end, { desc = 'Pick a buffer' })

    ctx:action('view.buffers', 'Open buffer picker', function()
        IDE.commands:execute('IDEBuffers')
    end)
end

return BufferPicker
