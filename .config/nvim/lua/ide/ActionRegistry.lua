-- ActionRegistry: named actions that keymaps and menus reference.
-- Instead of inline functions, extensions register named actions.
-- Keymaps bind to action names, enabling remapping without code changes.
--
-- Usage:
--   IDE.actions:register('editor.save', { desc = 'Save buffer', fn = function() ... end })
--   IDE.actions:register('editor.undo', { desc = 'Undo', fn = function() ... end })
--   IDE.actions:execute('editor.save')
--   ctx:keymap('n', '<C-s>', 'editor.save')  -- binds to action name

local EventEmitter = require 'ide.EventEmitter'

local ActionRegistry = Class('ActionRegistry')
Class.include(ActionRegistry, EventEmitter)

function ActionRegistry:init()
    self._actions = {} ---@type table<string, { desc: string, fn: function, category?: string }>
end

--- Register a named action.
---@param name string # dot-separated name like 'editor.save', 'file.open'
---@param opts { desc: string, fn: function, category?: string }
function ActionRegistry:register(name, opts)
    self._actions[name] = {
        desc = opts.desc or name,
        fn = opts.fn,
        category = opts.category or name:match('^([^.]+)'),
    }
end

--- Unregister a named action.
---@param name string
function ActionRegistry:unregister(name)
    self._actions[name] = nil
end

--- Build an action context from the current editor state.
--- Contains the buffer and window that should be the target of the action.
---@return { buf: Buffer, win: Window }
function ActionRegistry:_build_context()
    local Buffer = require 'ide.Buffer'
    local Window = require 'ide.Window'
    return {
        buf = Buffer.current(),
        win = Window.current(),
    }
end

--- Execute a named action with explicit context.
--- If no context is given, one is built from the current editor state.
---@param name string
---@param ctx? { buf: Buffer, win: Window }
---@return boolean # true if action existed and ran
function ActionRegistry:execute(name, ctx)
    local action = self._actions[name]
    if action and action.fn then
        ctx = ctx or self:_build_context()
        action.fn(ctx)
        self:emit('execute', name, ctx)
        return true
    end
    return false
end

--- Check if an action exists.
---@param name string
---@return boolean
function ActionRegistry:has(name)
    return self._actions[name] ~= nil
end

--- Get action description.
---@param name string
---@return string|nil
function ActionRegistry:desc(name)
    local a = self._actions[name]
    return a and a.desc or nil
end

--- List all actions, optionally filtered by category.
---@param category? string
---@return { name: string, desc: string, category: string }[]
function ActionRegistry:list(category)
    local result = {}
    for name, a in pairs(self._actions) do
        if not category or a.category == category then
            result[#result + 1] = { name = name, desc = a.desc, category = a.category }
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

--- List all unique categories.
---@return string[]
function ActionRegistry:categories()
    local cats = {}
    local seen = {}
    for _, a in pairs(self._actions) do
        if a.category and not seen[a.category] then
            seen[a.category] = true
            cats[#cats + 1] = a.category
        end
    end
    table.sort(cats)
    return cats
end

--- Get action count.
---@return integer
function ActionRegistry:count()
    return vim.tbl_count(self._actions)
end

---@return string
function ActionRegistry:__tostring()
    return string.format('ActionRegistry(%d actions)', self:count())
end

return ActionRegistry
