local icons = require 'ui.icons'
local progress = require 'ui.progress'

local function init(client)
    ---@type table<string, boolean>
    local running_adapters = {}

    client.listeners.run = function(adapter_id, _, _)
        ---@cast adapter_id string

        running_adapters[adapter_id] = true
        progress.update('neotest', {
            fn = function()
                return next(running_adapters) ~= nil
            end,
            ctx = icons.UI.Test .. ' Running tests',
        })
    end

    client.listeners.results = function(adapter_id, _, partial)
        ---@cast adapter_id string
        ---@cast partial boolean

        if not partial then
            running_adapters[adapter_id] = nil
        end
    end
end

---@class testing.neotest_progress_consumer
local M = {}

M = setmetatable(M, {
    __call = function(_, ...)
        return init(...)
    end,
})

return M
