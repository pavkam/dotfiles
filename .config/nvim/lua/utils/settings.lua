local utils = require 'utils'

local cache = {}
local auto_func = 0

local function _(name, buffer)
    assert(type(name) == 'string' and name ~= '')

    if buffer then
        name = buffer .. '_' .. name
    end
    return name
end

local function get(name, buffer)
    return cache[_(name, buffer)] or {}
end

local function set(name, buffer, value)
    cache[_(name, buffer)] = value
end

-- Clear the transient options for a buffer
utils.on_event({ 'LspDetach', 'LspAttach', 'BufWritePost' }, function(evt)
    set('transient', evt.buf, {})
end)

utils.on_event({ 'BufDelete' }, function(evt)
    set('transient', evt.buf, nil)
    set('permanent', evt.buf, nil)
end)

local M = {}

function M.get_transient_for_buffer(buffer, option, default)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local val = get('transient', buffer)[utils.stringify(option)]
    if val == nil then
        val = default
    end

    return val
end

function M.set_transient_for_buffer(buffer, option, value)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local tbl = get('transient', buffer)
    tbl[utils.stringify(option)] = value

    set('transient', buffer, tbl)
end

function M.transient(func, name)
    assert(type(func) == 'function')

    auto_func = auto_func + 1
    local var_name = name or tostring(auto_func)

    return function()
        local buffer = vim.api.nvim_get_current_buf()
        local val = M.get_transient_for_buffer(buffer, var_name)
        if val == nil then
            val = func(buffer)
            M.set_transient_for_buffer(buffer, var_name, val)
        end

        return val
    end
end

function M.get_permanent_for_buffer(buffer, option, default)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local val = get('permanent', buffer)[utils.stringify(option)]
    if val == nil then
        val = default
    end

    return val
end

function M.set_permanent_for_buffer(buffer, option, value)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local tbl = get('permanent', buffer)

    tbl[utils.stringify(option)] = value

    set('permanent', buffer, tbl)
end

function M.get_global(option, default)
    local val = get('global')[utils.stringify(option)]
    if val == nil then
        val = default
    end

    return val
end

function M.set_global(option, value)
    local tbl = get 'global'
    tbl[utils.stringify(option)] = value

    set('global', nil, tbl)
end

vim.api.nvim_create_user_command('DebugBufferSettings', function()
    local lsp = require "utils.lsp"
    local project = require "utils.project"

    local buffer = vim.api.nvim_get_current_buf()
    local settings = {
        project = {
            lsp_roots = lsp.roots(buffer),
            roots = project.roots(buffer),
            type = project.type(buffer),
        },
        transient = get('transient', buffer),
        permanent = get('permanent', buffer),
        global = get 'global',
    }

    require('noice').redirect(function()
        print(vim.inspect(settings))
    end)
end, { desc = 'Run Lazygit', nargs = 0 })

return M
