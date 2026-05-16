-- IDE UI Toolkit — lazy-loaded to avoid startup ordering issues.
local M = setmetatable({}, {
    __index = function(t, key)
        local ok, mod = pcall(require, 'ide.toolkit.' .. key)
        if ok then rawset(t, key, mod); return mod end
    end,
})

return M
