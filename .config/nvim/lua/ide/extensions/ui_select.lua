-- UI Select Extension: enhanced vim.ui.select using owned SelectPicker.
-- Overrides the default select popup with a TurboVision dialog.

local Extension = require 'ide.Extension'

local UISelect = Class('UISelect', Extension)

function UISelect:init()
    Extension.init(self, 'UISelect')
end

function UISelect:on_register(ctx)
    vim.ui.select = function(items, opts, on_choice)
        opts = opts or {}
        local SelectPicker = require 'ide.toolkit.SelectPicker'
        local formatted = {}
        for i, item in ipairs(items) do
            local text = opts.format_item and opts.format_item(item) or tostring(item)
            formatted[#formatted + 1] = { text = text, value = item, _index = i }
        end

        SelectPicker({
            title = opts.prompt or 'Select',
            items = formatted,
            on_select = function(sel)
                on_choice(sel.value, sel._index)
            end,
        }):show()
    end
end

return UISelect
