-- VNode: virtual node for the reactive UI tree.
-- Lightweight data class describing what to render.
-- tag can be a string (primitive: 'Label', 'HBox', 'VBox', 'HLine')
-- or a Component class (composite).

local VNode = Class('VNode')

---@param tag string|table # primitive name or Component class
---@param props table|nil # properties
---@param children table|nil # child VNode list
function VNode:init(tag, props, children)
    self.tag = tag
    self.props = props or {}
    self.children = children or {}
    self.key = self.props.key
end

--- Create a Label VNode.
---@param text string
---@param hl string|nil
---@return VNode
function VNode.Label(text, hl)
    return VNode('Label', { text = text, hl = hl })
end

--- Create a horizontal line VNode.
---@param char string|nil
---@param hl string|nil
---@return VNode
function VNode.HLine(char, hl)
    return VNode('HLine', { char = char or '─', hl = hl })
end

--- Create a vertical box (stack children vertically).
---@param props table|nil
---@param children VNode[]
---@return VNode
function VNode.VBox(props, children)
    return VNode('VBox', props, children)
end

--- Create a horizontal box (lay out children horizontally).
---@param props table|nil
---@param children VNode[]
---@return VNode
function VNode.HBox(props, children)
    return VNode('HBox', props, children)
end

--- Create a spacer (fills available space).
---@return VNode
function VNode.Spacer()
    return VNode('Spacer', {})
end

--- Check if this is a primitive node (string tag).
---@return boolean
function VNode:is_primitive()
    return type(self.tag) == 'string'
end

--- Check if this is a composite node (Component class tag).
---@return boolean
function VNode:is_composite()
    return type(self.tag) == 'table'
end

---@return string
function VNode:__tostring()
    local tag_name = type(self.tag) == 'string' and self.tag
        or (self.tag.__name or 'Component')
    local child_count = #self.children
    if child_count > 0 then
        return string.format('VNode(%s, %d children)', tag_name, child_count)
    end
    return string.format('VNode(%s)', tag_name)
end

return VNode
