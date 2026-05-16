-- TreeView: hierarchical data component with expand/collapse.
-- Extends Panel. Renders a tree of TreeNodes with indentation, icons, and lazy child loading.
-- Used by FileTree (file explorer), and potentially outline/symbol views.

local Panel = require 'ide.toolkit.Panel'
local TreeNode = require 'ide.toolkit.TreeNode'
local StyledLine = require 'ide.toolkit.StyledLine'
local StyledText = require 'ide.toolkit.StyledText'

local TreeView = Class('TreeView', Panel)

---@class TreeViewOpts : PanelOpts
---@field render_node? fun(node: TreeNode, depth: integer): table  -- returns StyledLine
---@field on_select? fun(node: TreeNode)
---@field on_expand? fun(node: TreeNode, callback: fun(children: TreeNode[]))

---@param opts TreeViewOpts
function TreeView:init(opts)
    Panel.init(self, opts)
    self._render_node = opts.render_node or self._default_render_node
    self._on_select = opts.on_select
    self._on_expand = opts.on_expand
    self._root = nil           ---@type TreeNode|nil
    self._flat_nodes = {}      ---@type TreeNode[]  -- flattened visible nodes (1-indexed, maps to buffer lines)
    self._nodes_by_id = {}     ---@type table<string, TreeNode>
end

--- Set the root node of the tree.
---@param root TreeNode
function TreeView:set_root(root)
    self._root = root
    self:_index_node(root, 0, nil)
    self:render()
end

--- Register a node and ALL its children in the index (for get_node lookups).
function TreeView:_index_node(node, depth, parent_id)
    node.depth = depth
    node.parent_id = parent_id
    self._nodes_by_id[node.id] = node
    if node.children then
        for _, child in ipairs(node.children) do
            self:_index_node(child, depth + 1, node.id)
        end
    end
end

--- Rebuild the index from root.
function TreeView:_rebuild_index()
    self._nodes_by_id = {}
    if self._root then
        self:_index_node(self._root, 0, nil)
    end
end

--- Flatten the visible tree into a list of nodes (for rendering).
---@return TreeNode[]
function TreeView:_flatten()
    local result = {}
    local function recurse(node)
        result[#result + 1] = node
        if node.children and node.is_expanded then
            for _, child in ipairs(node.children) do
                recurse(child)
            end
        end
    end
    if self._root then
        if self._root.children then
            for _, child in ipairs(self._root.children) do
                recurse(child)
            end
        else
            recurse(self._root)
        end
    end
    return result
end

--- Get the node at the current cursor line.
---@return TreeNode|nil
function TreeView:node_at_cursor()
    if not self._win or not self._win:is_valid() then return nil end
    local row = self._win:cursor().row
    return self._flat_nodes[row]
end

--- Get a node by id.
---@param id string
---@return TreeNode|nil
function TreeView:get_node(id)
    return self._nodes_by_id[id]
end

--- Expand a node. If on_expand is set, calls it for lazy loading.
---@param node TreeNode
function TreeView:expand(node)
    if not node:has_children() then return end
    if node.is_expanded then return end

    if not node.children or #node.children == 0 then
        -- Lazy load children
        if self._on_expand then
            self._on_expand(node, function(children)
                node.children = children
                node:expand()
                self:_rebuild_index()
                self:render()
            end)
            return
        end
    end

    node:expand()
    self:_rebuild_index()
    self:render()
end

--- Collapse a node.
---@param node TreeNode
function TreeView:collapse(node)
    if not node.is_expanded then return end
    node:collapse()
    self:_rebuild_index()
    self:render()
end

--- Toggle expand/collapse for a node.
---@param node TreeNode
function TreeView:toggle_node(node)
    if node.is_expanded then
        self:collapse(node)
    else
        self:expand(node)
    end
end

--- Focus (scroll to) a specific node by id.
---@param id string
function TreeView:focus_node(id)
    for i, node in ipairs(self._flat_nodes) do
        if node.id == id then
            if self._win and self._win:is_valid() then
                local Position = require 'ide.Position'
                self._win:set_cursor(Position(i, 1))
            end
            return
        end
    end
end

--- Set children for a node and re-render.
---@param node_id string
---@param children TreeNode[]
function TreeView:set_children(node_id, children)
    local node = self._nodes_by_id[node_id]
    if node then
        node.children = children
        node:expand()
        self:_rebuild_index()
        self:render()
    end
end

--- Render the tree into the panel buffer.
function TreeView:render()
    if not self:is_visible() then return end

    self._flat_nodes = self:_flatten()
    local lines = {}
    for _, node in ipairs(self._flat_nodes) do
        lines[#lines + 1] = self._render_node(node, node.depth)
    end

    if #lines == 0 then
        self:set_lines({ '  (empty)' })
        return
    end

    -- Check if lines are StyledLine objects or plain strings
    if type(lines[1]) == 'table' and lines[1].render then
        self:set_styled_lines(lines)
    else
        self:set_lines(lines)
    end
end

--- Default node renderer.
---@param node TreeNode
---@param depth integer
---@return StyledLine
function TreeView:_default_render_node(node, depth)
    local line = StyledLine()
    local indent = string.rep('  ', depth)
    local icon = node:has_children()
        and (node.is_expanded and '▾ ' or '▸ ')
        or '  '
    line:append(StyledText(indent .. icon, 'Comment'))
    line:append(StyledText(node.name, node.type == 'directory' and 'Directory' or 'Normal'))
    return line
end

function TreeView:_on_mount()
    local tv = self

    -- Enter/l = select or expand
    self:map('n', '<CR>', function()
        local node = tv:node_at_cursor()
        if not node then return end
        if node:has_children() then
            tv:toggle_node(node)
        elseif tv._on_select then
            tv._on_select(node)
        end
    end)

    self:map('n', 'l', function()
        local node = tv:node_at_cursor()
        if not node then return end
        if node:has_children() and not node.is_expanded then
            tv:expand(node)
        elseif tv._on_select then
            tv._on_select(node)
        end
    end)

    -- h = collapse or go to parent
    self:map('n', 'h', function()
        local node = tv:node_at_cursor()
        if not node then return end
        if node.is_expanded then
            tv:collapse(node)
        elseif node.parent_id then
            tv:focus_node(node.parent_id)
        end
    end)

    -- Render initial content
    self:render()
end

---@return string
function TreeView:__tostring()
    return string.format('TreeView(%s, %d nodes)', self._title, #self._flat_nodes)
end

return TreeView
