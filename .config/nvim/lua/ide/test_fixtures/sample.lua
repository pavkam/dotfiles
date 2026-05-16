-- Sample Lua file for testing
local M = {}

---@param name string
---@return string
function M.greet(name)
    return 'Hello, ' .. name .. '!'
end

function M.add(a, b)
    return a + b
end

return M
