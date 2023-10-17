local utils = require "utils"

local M = {}

function M.active_names_for_buffer(buffer)
    local conform = require "conform"

    buffer = buffer or vim.api.nvim_get_current_buf()

    local ok, formatters = pcall(conform.list_formatters, buffer)

    if not ok then
        return {}
    end

    return vim.tbl_map(function(v) return v.name end, formatters)
end

function M.active_for_buffer(buffer)
    local conform = require "conform"

    buffer = buffer or vim.api.nvim_get_current_buf()

    local ok, formatters = pcall(conform.list_formatters, buffer)

    return ok and #formatters > 0
end

function M.apply(buffer, injected)
    local conform = require "conform"

    buffer = buffer or vim.api.nvim_get_current_buf()

    local additional = injected and { formatters = { "injected" } } or {}

    conform.format(utils.tbl_merge({ bufnr = buffer }, additional))
end

function M.enabled_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local enabled = vim.b[buffer].conform_auto_format_enabled
    if enabled == nil or enabled == true then
        return true
    end

    return false
end

function M.toggle_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local enabled = M.enabled_for_buffer(buffer)
    if enabled then
        utils.info("Turning off auto-formatting for buffer.")
        vim.b[buffer].format_enabled = false
    else
        utils.info("Turning on auto-formatting for buffer.")
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

    if enabled then
        utils.info("Turning off auto-formatting globally.")
        vim.g.format_enabled = false
    else
        utils.info("Turning on auto-formatting globally.")
        vim.g.format_enabled = true
    end
end

return M
