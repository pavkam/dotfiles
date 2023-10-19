local utils = require "utils"

local M = {}

local function formatters(buffer)
    local conform = require "conform"
    local ok, formatters = pcall(conform.list_formatters, buffer)

    if not ok then
        return {}
    end

    return vim.tbl_map(function(v) return v.name end, formatters)
end

function M.active_names_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return formatters(buffer)
end

function M.active_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return #formatters(buffer) > 0
end

function M.apply(buffer, injected)
    local conform = require "conform"

    buffer = buffer or vim.api.nvim_get_current_buf()

    if not vim.api.nvim_buf_is_valid(buffer) then
        return
    end

    local additional = injected and { formatters = { "injected" } } or {}

    conform.format(utils.tbl_merge({ bufnr = buffer }, additional))
end

function M.enabled_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local enabled = vim.api.nvim_buf_is_valid(buffer) and vim.b[buffer].conform_auto_format_enabled
    if enabled == nil or enabled == true then
        return true
    end

    return false
end

function M.toggle_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local enabled = M.enabled_for_buffer(buffer)

    utils.info(string.format("Turning **%s** auto-formatting for *%s*.", enabled and "off" or "on", vim.fn.expand("%:t")))
    vim.b[buffer].format_enabled = not enabled

    if enabled then
        vim.b[buffer].format_enabled = false
    else
        vim.b[buffer].format_enabled = true
    end
end

function M.enabled()
    local enabled = vim.g.format_enabled
    if enabled == nil or enabled == true then
        return true
    end

    return false
end

function M.toggle()
    local enabled = M.enabled()

    utils.info(string.format("Turning **%s** auto-formatting *globally*.", enabled and "off" or "on"))
    vim.g.format_enabled = not enabled

    if enabled then
        vim.g.format_enabled = false
    else
        vim.g.format_enabled = true
    end
end

return M
