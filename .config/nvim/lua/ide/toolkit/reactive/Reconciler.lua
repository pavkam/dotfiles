-- Reconciler: diffs old and new VNode trees to produce minimal patches.
-- Compares tag, key, and props to determine mount/unmount/update operations.

local Reconciler = {}

---@class DiffPatch
---@field type 'mount'|'unmount'|'update'|'reorder'
---@field vnode table|nil
---@field old table|nil
---@field new table|nil

--- Diff two VNode trees and return a list of patches.
---@param old_tree table|nil # previous VNode tree
---@param new_tree table|nil # new VNode tree
---@return DiffPatch[]
function Reconciler.diff(old_tree, new_tree)
    local patches = {}

    if not old_tree and not new_tree then
        return patches
    end

    if not old_tree and new_tree then
        patches[#patches + 1] = { type = 'mount', vnode = new_tree }
        return patches
    end

    if old_tree and not new_tree then
        patches[#patches + 1] = { type = 'unmount', vnode = old_tree }
        return patches
    end

    -- Tags differ — full replace
    if old_tree.tag ~= new_tree.tag then
        patches[#patches + 1] = { type = 'unmount', vnode = old_tree }
        patches[#patches + 1] = { type = 'mount', vnode = new_tree }
        return patches
    end

    -- Same tag — check props
    if not Reconciler._props_equal(old_tree.props, new_tree.props) then
        patches[#patches + 1] = { type = 'update', old = old_tree, new = new_tree }
    end

    -- Reconcile children
    Reconciler._diff_children(old_tree.children or {}, new_tree.children or {}, patches)

    return patches
end

--- Shallow compare two props tables.
--- Functions are ignored (inline closures always differ).
---@param a table
---@param b table
---@return boolean
function Reconciler._props_equal(a, b)
    if a == b then return true end
    if not a or not b then return false end

    for k, v in pairs(a) do
        if k ~= 'key' and type(v) ~= 'function' then
            if b[k] ~= v then return false end
        end
    end
    for k, v in pairs(b) do
        if k ~= 'key' and type(v) ~= 'function' then
            if a[k] ~= v then return false end
        end
    end
    return true
end

--- Diff two lists of children.
---@param old_children table[]
---@param new_children table[]
---@param patches DiffPatch[]
function Reconciler._diff_children(old_children, new_children, patches)
    local old_keyed, old_unkeyed = Reconciler._partition_by_key(old_children)
    local new_keyed, new_unkeyed = Reconciler._partition_by_key(new_children)

    -- Match keyed children
    local matched_old = {}
    for key, new_child in pairs(new_keyed) do
        local old_child = old_keyed[key]
        if old_child then
            local child_patches = Reconciler.diff(old_child, new_child)
            for _, p in ipairs(child_patches) do patches[#patches + 1] = p end
            matched_old[key] = true
        else
            patches[#patches + 1] = { type = 'mount', vnode = new_child }
        end
    end

    -- Unmount removed keyed children
    for key, old_child in pairs(old_keyed) do
        if not matched_old[key] then
            patches[#patches + 1] = { type = 'unmount', vnode = old_child }
        end
    end

    -- Match unkeyed children by position
    local max_len = math.max(#old_unkeyed, #new_unkeyed)
    for i = 1, max_len do
        local child_patches = Reconciler.diff(old_unkeyed[i], new_unkeyed[i])
        for _, p in ipairs(child_patches) do patches[#patches + 1] = p end
    end
end

--- Partition children into keyed (by key prop) and unkeyed (ordered list).
---@param children table[]
---@return table<string, table>, table[]
function Reconciler._partition_by_key(children)
    local keyed = {}
    local unkeyed = {}
    for _, child in ipairs(children) do
        if child.key then
            keyed[child.key] = child
        else
            unkeyed[#unkeyed + 1] = child
        end
    end
    return keyed, unkeyed
end

--- Count patches by type (for diagnostics).
---@param patches DiffPatch[]
---@return { mount: integer, unmount: integer, update: integer }
function Reconciler.stats(patches)
    local counts = { mount = 0, unmount = 0, update = 0 }
    for _, p in ipairs(patches) do
        counts[p.type] = (counts[p.type] or 0) + 1
    end
    return counts
end

return Reconciler
