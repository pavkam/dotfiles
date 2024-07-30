local icons = require 'ui.icons'

---@class (strict) core.keys
local M = {}

---@alias core.keys.KeyMapMode 'n' | 'v' | 'V' | 'c' | 's' | 'x' | 'i' | 'o' | 't' # the mode to map the key in

---@class (strict) core.keys.KeyMapOpts # the options to pass to the keymap
---@field buffer integer|nil # whether the keymap is buffer-local
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
    local using_which_key = package.loaded['lazy'] and require('lazy.core.config').spec.plugins['which-key.nvim'] ~= nil

    if using_which_key then
        local wk = require 'which-key'
        wk.add {
            lhs = key,
            rhs = action,
            desc = opts.desc,
            icon = opts.icon,
            silent = opts.silent,
            expr = opts.expr,
            noremap = opts.noremap,
            nowait = opts.nowait,
            buffer = opts.buffer,
            mode = mode,
        }
    else
        vim.keymap.set(mode, key, action, {
            silent = opts.silent,
            expr = opts.expr,
            noremap = opts.noremap,
            nowait = opts.nowait,
            buffer = opts.buffer,
            desc = opts.icon and icons.iconify(opts.icon, opts.desc) or opts.desc,
        })
    end
end

---@class (strict) core.keys.KeyGroupOpts # the options to pass to the key group
---@field lhs string # the key to decorate
---@field icon string|nil # the icon of the key group
---@field desc string|nil # the description of the key group
---@field buffer integer|nil # whether the key group is buffer-local
---@field mode core.keys.KeyMapMode|core.keys.KeyMapMode[] # the mode(s) to map the key group in

--- Registers a key group
---@param opts core.keys.KeyGroupOpts # the options to pass to the key group
function M.group(opts)
    local using_which_key = package.loaded['lazy'] and require('lazy.core.config').spec.plugins['which-key.nvim'] ~= nil

    if using_which_key then
        local wk = require 'which-key'
        wk.add { opts.lhs, opts.mode, icon = opts.icon, group = opts.desc, buffer = opts.buffer }
    end
end

return M
