-- Lightweight class system for OOP abstractions over vim APIs.
-- Provides single inheritance, constructors, type checking, and mixins.
-- All IDE domain objects (Buffer, Window, Extension, etc.) use this system.
--
-- Usage:
--   local Animal = Class('Animal')
--   function Animal:init(name) self.name = name end
--   function Animal:speak() return self.name end
--
--   local Dog = Class('Dog', Animal)
--   function Dog:init(name) Animal.init(self, name) end
--   function Dog:speak() return self.name .. ' barks' end
--
--   local d = Dog('Rex')
--   print(d:speak())       --> "Rex barks"
--   print(d:is_a(Animal))  --> true
--   print(Class.name(d))   --> "Dog"

---@class ClassDefinition
---@field __name string
---@field __super ClassDefinition|nil
---@field init fun(self: table, ...)|nil

---@param name string # class name for debugging and introspection
---@param super ClassDefinition|nil # optional superclass
---@return ClassDefinition
local function new_class(name, super)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
    }

    local cls = { __name = name, __super = super }
    cls.__index = cls

    if super then
        setmetatable(cls, {
            __index = super,
            __call = function(self, ...)
                local instance = setmetatable({}, self)
                if instance.init then
                    instance:init(...)
                end
                return instance
            end,
        })
    else
        setmetatable(cls, {
            __call = function(self, ...)
                local instance = setmetatable({}, self)
                if instance.init then
                    instance:init(...)
                end
                return instance
            end,
        })
    end

    -- Default __tostring if not provided by the class
    if not cls.__tostring then
        cls.__tostring = function(self)
            return name .. '()'
        end
    end

    --- Checks if this instance is of a given class (or a subclass of it).
    ---@param target ClassDefinition # the class to check against
    ---@return boolean
    function cls:is_a(target)
        local current = getmetatable(self)
        while current do
            if current == target then
                return true
            end
            local mt = getmetatable(current)
            current = mt and mt.__index or nil
        end
        return false
    end

    return cls
end

-- The Class module: callable to create new classes, with utility methods.
---@class ClassModule
---@overload fun(name: string, super?: ClassDefinition): ClassDefinition
local M = setmetatable({}, {
    __call = function(_, name, super)
        return new_class(name, super)
    end,
})

--- Gets the class name of an instance or class.
---@param obj table # the instance or class
---@return string|nil
function M.name(obj)
    local mt = getmetatable(obj)
    if mt and mt.__name then
        return mt.__name
    end
    return obj.__name
end

--- Gets the superclass of a class.
---@param cls ClassDefinition # the class
---@return ClassDefinition|nil
function M.super(cls)
    return cls.__super
end

--- Mixes methods from a table into a class.
--- Does not overwrite existing methods.
---@param cls ClassDefinition # the target class
---@param mixin table<string, function> # the methods to mix in
function M.include(cls, mixin)
    xassert {
        mixin = { mixin, 'table' },
    }

    for key, value in pairs(mixin) do
        if cls[key] == nil then
            cls[key] = value
        end
    end
end

return M
