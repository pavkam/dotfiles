-- Provides async functions for the API.
---@class api.async
local M = {}

--- Polls a function until it returns a "falsy" value.
---@param fn fun(...): any # the function to call.
---@param interval integer # the interval in milliseconds.
function M.poll(fn, interval, ...)
    local timer = vim.uv.new_timer()

    local args = { ... }
    assert(timer:start(
        0,
        interval,
        vim.schedule_wrap(function()
            if not fn(unpack(args)) then
                timer:stop()
            end
        end)
    ))
end

--- Defers a function call (per buffer) in LIFO mode.
--- If the function is called again before the timeout,
--- the timer is reset.
---@param fn fun(buffer: integer, ...) # the function to call.
---@param wait integer # the wait time in milliseconds.
---@return fun(buffer: integer, ...) # the debounced function.
function M.debounce(fn, wait)
    ---@type table<integer, uv_timer_t>
    local timers = {}

    ---@type vim.DebouncedFn
    return function(buffer, ...)
        buffer = buffer or vim.api.nvim_get_current_buf()

        assert(vim.api.nvim_buf_is_valid(buffer))

        local timer = timers[buffer]
        if not timer then
            timer = vim.uv.new_timer()
            timers[buffer] = timer
        else
            timer:stop()
        end

        local args = { ... }
        assert(timer:start(
            wait,
            0,
            vim.schedule_wrap(function()
                timer:stop()

                if vim.api.nvim_buf_is_valid(buffer) then
                    vim.api.nvim_buf_call(buffer, function()
                        fn(buffer, unpack(args))
                    end)
                end
            end)
        ))
    end
end

return table.freeze(M)
