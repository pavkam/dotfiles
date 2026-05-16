-- show: convenience function to display a reactive Component in a Panel.
-- Bridges the reactive Component world with Panel keybindings.

local ReactivePanel = require 'ide.toolkit.reactive.ReactivePanel'

--- Show a reactive component in a floating panel.
---@param component table # Component instance
---@param opts { title?: string, width?: number, height?: number, keys?: table<string, function> }|nil
---@return ReactivePanel
local function show(component, opts)
    opts = opts or {}
    local panel = ReactivePanel(component, {
        title = opts.title,
        width = opts.width,
        height = opts.height,
    })

    panel:show()

    -- Bind optional keymaps
    if opts.keys and panel:buffer() then
        for key, fn in pairs(opts.keys) do
            panel:map('n', key, fn)
        end
    end

    return panel
end

return show
