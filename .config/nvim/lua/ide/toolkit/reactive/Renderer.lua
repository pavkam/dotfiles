-- Renderer: paints a laid-out VNode tree onto a Canvas.
-- After Layout.compute assigns bounds, Renderer.paint draws primitives.

local Canvas = require 'ide.toolkit.Canvas'

local Renderer = {}

--- Paint a VNode tree onto a Canvas.
---@param vnode table # VNode with _layout assigned
---@param canvas Canvas
function Renderer.paint(vnode, canvas)
    local tag = vnode.tag
    local layout = vnode._layout
    if not layout then return end

    if tag == 'Label' then
        Renderer._paint_label(vnode, canvas)
    elseif tag == 'HLine' then
        Renderer._paint_hline(vnode, canvas)
    elseif tag == 'Spacer' then
        -- Nothing to paint
    elseif tag == 'VBox' or tag == 'HBox' then
        for _, child in ipairs(vnode.children) do
            Renderer.paint(child, canvas)
        end
    end
end

--- Paint a Label onto the canvas.
---@param vnode table
---@param canvas Canvas
function Renderer._paint_label(vnode, canvas)
    local layout = vnode._layout
    local text = vnode.props.text or ''
    local hl = vnode.props.hl
    canvas:text(layout.row, layout.col, text, hl)
end

--- Paint a horizontal line.
---@param vnode table
---@param canvas Canvas
function Renderer._paint_hline(vnode, canvas)
    local layout = vnode._layout
    local char = vnode.props.char or '─'
    local hl = vnode.props.hl
    canvas:hline(layout.row, layout.col, layout.width, char, hl)
end

--- Render a full Component: call render(), compute layout, paint to canvas.
---@param component table # Component instance (mounted)
---@param bounds LayoutBounds
---@return Canvas
function Renderer.render_component(component, bounds)
    local Layout = require 'ide.toolkit.reactive.Layout'
    local vnode = component._render_result
    if not vnode then return Canvas(bounds.width, bounds.height) end

    Layout.compute(vnode, bounds)
    local canvas = Canvas(bounds.width, bounds.height)
    Renderer.paint(vnode, canvas)
    return canvas
end

return Renderer
