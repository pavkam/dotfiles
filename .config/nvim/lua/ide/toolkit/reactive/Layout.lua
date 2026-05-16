-- Layout: computes position and size for VNode trees.
-- Takes a VNode tree and a bounding box, assigns { row, col, width, height }
-- to every node. Supports VBox (vertical stack), HBox (horizontal), and
-- primitive intrinsic sizing (Label, HLine).

local Layout = {}

---@class LayoutBounds
---@field row integer # 1-indexed
---@field col integer # 1-indexed
---@field width integer
---@field height integer

--- Compute intrinsic height of a VNode subtree.
---@param vnode table # VNode
---@param available_width integer
---@return integer
function Layout.measure_height(vnode, available_width)
    local tag = vnode.tag
    if tag == 'Label' then
        return 1
    elseif tag == 'HLine' then
        return 1
    elseif tag == 'Spacer' then
        return vnode.props.height or 1
    elseif tag == 'VBox' then
        local total = 0
        local spacing = vnode.props.spacing or 0
        local padding = vnode.props.padding or 0
        for i, child in ipairs(vnode.children) do
            total = total + Layout.measure_height(child, available_width - padding * 2)
            if i < #vnode.children then total = total + spacing end
        end
        return total + padding * 2
    elseif tag == 'HBox' then
        local max_h = 0
        for _, child in ipairs(vnode.children) do
            local h = Layout.measure_height(child, available_width)
            if h > max_h then max_h = h end
        end
        return max_h
    end
    return 1
end

--- Compute intrinsic width of a VNode.
---@param vnode table # VNode
---@return integer
function Layout.measure_width(vnode)
    local tag = vnode.tag
    if tag == 'Label' then
        local text = vnode.props.text or ''
        return vim.api.nvim_strwidth(text)
    elseif tag == 'HLine' then
        return 0 -- fills available width
    elseif tag == 'Spacer' then
        return 0 -- fills available width
    elseif tag == 'VBox' then
        local max_w = 0
        for _, child in ipairs(vnode.children) do
            local w = Layout.measure_width(child)
            if w > max_w then max_w = w end
        end
        local padding = vnode.props.padding or 0
        return max_w + padding * 2
    elseif tag == 'HBox' then
        local total = 0
        local spacing = vnode.props.spacing or 0
        for i, child in ipairs(vnode.children) do
            total = total + Layout.measure_width(child)
            if i < #vnode.children then total = total + spacing end
        end
        return total
    end
    return 0
end

--- Recursively assign layout bounds to every node in a VNode tree.
---@param vnode table # VNode
---@param bounds LayoutBounds
function Layout.compute(vnode, bounds)
    vnode._layout = {
        row = bounds.row,
        col = bounds.col,
        width = bounds.width,
        height = bounds.height,
    }

    local tag = vnode.tag
    if tag == 'VBox' then
        Layout._layout_vbox(vnode, bounds)
    elseif tag == 'HBox' then
        Layout._layout_hbox(vnode, bounds)
    end
end

--- Layout children in a vertical stack.
---@param vnode table
---@param bounds LayoutBounds
function Layout._layout_vbox(vnode, bounds)
    local padding = vnode.props.padding or 0
    local spacing = vnode.props.spacing or 0
    local inner_row = bounds.row + padding
    local inner_col = bounds.col + padding
    local inner_width = bounds.width - padding * 2

    for i, child in ipairs(vnode.children) do
        local child_height = Layout.measure_height(child, inner_width)
        Layout.compute(child, {
            row = inner_row,
            col = inner_col,
            width = inner_width,
            height = child_height,
        })
        inner_row = inner_row + child_height + spacing
    end
end

--- Layout children in a horizontal row.
---@param vnode table
---@param bounds LayoutBounds
function Layout._layout_hbox(vnode, bounds)
    local spacing = vnode.props.spacing or 0
    local children = vnode.children

    -- Measure intrinsic widths
    local widths = {}
    local total_intrinsic = 0
    local spacer_count = 0
    for i, child in ipairs(children) do
        if child.tag == 'Spacer' then
            widths[i] = 0
            spacer_count = spacer_count + 1
        else
            widths[i] = Layout.measure_width(child)
            total_intrinsic = total_intrinsic + widths[i]
        end
    end

    -- Distribute remaining space to spacers
    local total_spacing = math.max(0, (#children - 1)) * spacing
    local remaining = bounds.width - total_intrinsic - total_spacing
    if spacer_count > 0 and remaining > 0 then
        local per_spacer = math.floor(remaining / spacer_count)
        for i, child in ipairs(children) do
            if child.tag == 'Spacer' then widths[i] = per_spacer end
        end
    end

    -- Assign bounds
    local col = bounds.col
    for i, child in ipairs(children) do
        Layout.compute(child, {
            row = bounds.row,
            col = col,
            width = widths[i],
            height = bounds.height,
        })
        col = col + widths[i] + spacing
    end
end

return Layout
