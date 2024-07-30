---@class core.keys
local M = {}

---@alias core.keys.KeyMapMode 'n' | 'v' | 'V' | 'c' | 's' | 'x' | 'i' | 'o' | 't' # the mode to map the key in

---@class core.keys.KeyMapOpts # the options to pass to the keymap
---@field buffer boolean|nil # whether the keymap is buffer-local
---@field silent boolean|nil # whether the keymap is silent
---@field expr boolean|nil # whether the keymap is an expression
---@field noremap boolean|nil # whether the keymap is non-recursive
---@field nowait boolean|nil # whether the keymap is nowait
---@field desc string|nil # the description of the keymap
---@field icon string|nil # the icon of the keymap

--- Maps a key to an action
--- @param mode core.keys.KeyMapMode|core.keys.KeyMapMode[] # the mode(s) to map the key in
--- @param key string # the key to map
--- @param action string|function # the action to map the key to
--- @param opts core.keys.KeyMapOpts|nil # the options to pass to the keymap
function M.map(mode, key, action, opts)
    opts = opts or {}

    local silent = opts.silent or false
    local expr = opts.expr or false
    local noremap = opts.noremap or true
    local nowait = opts.nowait or false

    -- URGENT: Fix this when updating to the which key
    local using_which_key = false -- package.loaded['lazy'] and require('lazy.core.config').spec.plugins['which-key.nvim'] ~= nil

    if using_which_key then
        local wk = require 'which-key'
        wk.add {
            lhs = key,
            rhs = action,
            desc = opts.desc,
            icon = opts.icon,
            silent = silent,
            expr = expr,
            noremap = noremap,
            nowait = nowait,
        }
    else
        vim.keymap.set(mode, key, action, {
            silent = silent,
            expr = expr,
            noremap = noremap,
            nowait = nowait,
            buffer = opts.buffer,
            desc = opts.icon and (opts.icon .. ' ' .. opts.desc) or opts.desc,
        })
    end
end

return M
