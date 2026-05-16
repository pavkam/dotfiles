-- component.lua: Function component runtime.
-- Bridges function components with hooks to the buffer/window rendering system.
--
-- Usage:
--   local C = require('ide.toolkit.component')
--   local instance = C.mount(MyComponent, { title = 'Hello' }, target_buf)
--   -- later:
--   C.unmount(instance)

local hooks = require 'ide.toolkit.hooks'
local Canvas = require 'ide.toolkit.Canvas'

local M = {}

---@class ComponentInstance
---@field ctx HookContext
---@field buf Buffer|nil
---@field win Window|nil
---@field width integer
---@field height integer
---@field children table<string, HookContext> # child component contexts keyed by position

--- Mount a function component into a buffer.
--- The component function receives props and returns a VNode tree (table).
--- Re-renders automatically when useState setters are called.
---@param component function
---@param props table
---@param buf Buffer
---@param win Window|nil
---@return ComponentInstance
function M.mount(component, props, buf, win)
    local instance = {
        buf = buf,
        win = win,
        children = {},
        width = win and win:width() or 80,
        height = win and win:height() or 24,
    }

    local function re_render()
        if not instance.buf or not instance.buf:is_valid() then return end
        if instance.win and instance.win:is_valid() then
            instance.width = instance.win:width()
            instance.height = instance.win:height()
        end
        M._render(instance)
    end

    instance.ctx = hooks.create_context(component, props, re_render)
    M._render(instance)
    return instance
end

--- Unmount a component instance, running effect cleanups.
---@param instance ComponentInstance
function M.unmount(instance)
    -- Clean up child component contexts
    for _, child_ctx in pairs(instance.children or {}) do
        hooks.cleanup(child_ctx)
    end
    instance.children = {}
    hooks.cleanup(instance.ctx)
    instance.buf = nil
    instance.win = nil
end

--- Update props and re-render.
---@param instance ComponentInstance
---@param new_props table
function M.update(instance, new_props)
    instance.ctx.props = new_props
    M._render(instance)
end

--- Internal: render the component to its buffer.
---@param instance ComponentInstance
function M._render(instance)
    local ctx = instance.ctx
    local buf = instance.buf
    if not buf or not buf:is_valid() then return end

    hooks.begin_render(ctx)
    local ok, tree = pcall(ctx.render_fn, ctx.props)
    hooks.end_render()

    local w = instance.width
    local h = instance.height
    local c = Canvas(w, h)

    if not ok then
        -- Error boundary: render error fallback instead of crashing
        local err_msg = tostring(tree):sub(1, w * 3)
        c:fill(1, 1, w, 1, ' ', 'ErrorMsg')
        c:text(1, 2, ' Component Error', 'ErrorMsg')
        local line = 3
        for part in err_msg:gmatch('[^\n]+') do
            if line > h then break end
            c:text(line, 2, part:sub(1, w - 2), 'IDEPanelDim')
            line = line + 1
        end
        c:render(buf)
        if instance.on_error then
            pcall(instance.on_error, tree)
        end
        vim.schedule(function()
            vim.notify('[IDE] Component render error: ' .. err_msg, vim.log.levels.WARN)
        end)
        return
    end

    M._render_tree(c, tree, 1, 1, w, h, instance)
    c:render(buf)

    -- Run effects after render
    hooks.run_effects(ctx)
end

--- Render a VNode tree onto a Canvas.
--- VNodes are tables with { type, ... } structure.
---@param canvas table # Canvas instance
---@param tree table|string # VNode or array of VNodes
---@param row integer
---@param col integer
---@param width integer
---@param height integer
function M._render_tree(canvas, tree, row, col, width, height, instance)
    if type(tree) == 'string' then
        canvas:text(row, col, tree)
        return
    end
    if not tree then return end

    -- Array of children
    if tree[1] and not tree.type then
        local r = row
        for i, child in ipairs(tree) do
            if r > row + height - 1 then break end
            M._render_tree(canvas, child, r, col, width, height - (r - row), instance)
            r = r + 1
        end
        return
    end

    local t = tree.type

    -- Nested function component
    if t == 'component' and tree.render and instance then
        local key = tree.key or tostring(row) .. ':' .. tostring(col)
        local child_ctx = instance.children[key]
        if not child_ctx then
            child_ctx = hooks.create_context(tree.render, tree.props or {}, instance.ctx.on_dirty)
            instance.children[key] = child_ctx
        else
            child_ctx.props = tree.props or {}
        end
        hooks.begin_render(child_ctx)
        local cok, child_tree = pcall(child_ctx.render_fn, child_ctx.props)
        hooks.end_render()
        if cok and child_tree then
            M._render_tree(canvas, child_tree, row, col, width, height, instance)
        end
        hooks.run_effects(child_ctx)
        return
    end

    if t == 'text' then
        canvas:text(row, col + (tree.indent or 0), tree.text or '', tree.hl or 'Normal')
    elseif t == 'fill' then
        canvas:fill(row, col, width, 1, tree.char or ' ', tree.hl or 'Normal')
    elseif t == 'separator' then
        canvas:hline(row, col, width, tree.char or '─', tree.hl or 'IDEDialogBorder')
    elseif t == 'row' then
        -- Render children horizontally
        if tree.hl then
            canvas:fill(row, col, width, 1, ' ', tree.hl)
        end
        local c = col
        for _, child in ipairs(tree.children or tree) do
            if type(child) == 'table' and child.type then
                M._render_tree(canvas, child, row, c, width - (c - col), 1, instance)
                c = c + vim.api.nvim_strwidth(child.text or '')
            end
        end
    elseif t == 'list' then
        local items = tree.items or {}
        local selected = tree.selected or 0
        local scroll = tree.scroll or 0
        local max_rows = math.min(#items - scroll, height)
        for i = 1, max_rows do
            local idx = i + scroll
            local item = items[idx]
            local item_row = row + i - 1
            if idx == selected then
                canvas:fill(item_row, col, width, 1, ' ', tree.selected_hl or 'IDEDialogListSelected')
                canvas:text(item_row, col + 1, '▸ ', tree.marker_hl or 'IDEDialogHotkey')
                canvas:text(item_row, col + 3, tree.format and tree.format(item) or tostring(item),
                    tree.selected_hl or 'IDEDialogListSelected')
            else
                canvas:text(item_row, col + 3, tree.format and tree.format(item) or tostring(item),
                    tree.item_hl or 'IDEDialogNormal')
            end
        end
    elseif t == 'input' then
        canvas:fill(row, col, width, 1, ' ', tree.hl or 'IDEDialogFocused')
        canvas:text(row, col + 1, (tree.icon or '') .. ' ', tree.icon_hl or 'IDEDialogHotkey')
        canvas:text(row, col + 3, (tree.value or '') .. '▏', tree.hl or 'IDEDialogFocused')
    elseif t == 'status' then
        canvas:fill(row, col, width, 1, ' ', tree.hl or 'IDEDialogBorder')
        local text = tree.text or ''
        canvas:right(row, text .. ' ', tree.text_hl or 'IDEDialogTitle')
    end
end

return M
