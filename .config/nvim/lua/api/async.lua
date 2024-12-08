-- Provides async functions for the API.
---@class async
local M = {}

--- Polls a function until it returns a "falsy" value.
---@param fn fun(...): any # the function to call.
---@param interval integer # the interval in milliseconds.
---@return fun() # the stop function.
function M.poll(fn, interval, ...)
    xassert {
        fn = { fn, 'callable' },
        interval = { interval, { 'number', ['>'] = 0 } },
    }

    local timer = vim.uv.new_timer()
    local args = { ... }

    assert(
        timer:start(
            0,
            interval,
            vim.schedule_wrap(function()
                if not fn(unpack(args)) then
                    timer:stop()
                end
            end)
        ),
        'failed to start timer'
    )

    return function()
        timer:stop()
    end
end

--- Defers a function call (per buffer) in LIFO mode.
--- If the function is called again before the timeout,
--- the timer is reset.
---@param fn fun(buffer_id: integer, ...) # the function to call.
---@param wait integer # the wait time in milliseconds.
---@return fun(buffer: integer, ...) # the debounced function.
function M.debounce(fn, wait)
    xassert {
        fn = { fn, 'callable' },
        wait = { wait, { 'integer', ['>'] = 0 } },
    }

    ---@type table<integer, uv_timer_t>
    local timers = {}

    ---@type fun(buffer_id: integer|nil, ...): any
    return function(buffer_id, ...)
        xassert {
            buffer_id = { buffer_id, { 'integer', ['>'] = -1 }, true },
        }

        buffer_id = buffer_id or vim.api.nvim_get_current_buf()

        assert(vim.api.nvim_buf_is_valid(buffer_id)) --TODO: use the buf

        local timer = timers[buffer_id]
        if not timer then
            timer = vim.uv.new_timer()
            timers[buffer_id] = timer
        else
            timer:stop()
        end

        local args = { ... }
        assert(timer:start(
            wait,
            0,
            vim.schedule_wrap(function()
                timer:stop()

                if vim.api.nvim_buf_is_valid(buffer_id) then
                    vim.api.nvim_buf_call(buffer_id, function()
                        fn(buffer_id, unpack(args))
                    end)
                end
            end)
        ))
    end
end

return table.freeze(M)
