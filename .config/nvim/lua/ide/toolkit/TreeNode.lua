-- TreeNode: value object for hierarchical tree data.
-- Used by TreeView for file explorers, outline views, etc.

local TreeNode = Class('TreeNode')

---@param opts { id: string, name: string, type?: string, data?: table, children?: TreeNode[], is_expanded?: boolean }
function TreeNode:init(opts)
    self.id = opts.id
    self.name = opts.name
    self.type = opts.type or 'item'       -- 'file', 'directory', 'item'
    self.data = opts.data or {}           -- arbitrary payload
    self.children = opts.children or nil  -- nil = leaf, {} = empty dir, [...] = loaded
    self.is_expanded = opts.is_expanded or false
    self.depth = 0
    self.parent_id = nil
end

---@return boolean
function TreeNode:has_children()
    return self.children ~= nil
end

---@return boolean
function TreeNode:is_leaf()
    return self.children == nil
end

function TreeNode:expand()
    self.is_expanded = true
end

function TreeNode:collapse()
    self.is_expanded = false
end

---@return string
function TreeNode:__tostring()
    return string.format('TreeNode(%s, %s)', self.name, self.type)
end

return TreeNode
