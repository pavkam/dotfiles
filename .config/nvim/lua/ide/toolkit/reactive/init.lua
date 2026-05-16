-- Reactive UI toolkit — lazy-loaded components.
local M = setmetatable({}, {
    __index = function(t, key)
        local ok, mod = pcall(require, 'ide.toolkit.reactive.' .. key)
        if ok then rawset(t, key, mod); return mod end
    end,
})

return M
