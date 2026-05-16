-- IDE Extensions: non-essential features that enhance the IDE.
-- Each extension is self-contained and can be enabled/disabled independently.
-- Extensions are loaded lazily — only when first accessed.

local M = setmetatable({}, {
    __index = function(t, key)
        local ok, mod = pcall(require, 'ide.extensions.' .. key)
        if ok then rawset(t, key, mod); return mod end
    end,
})

return M
