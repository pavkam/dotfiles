local utils = require "utils"

local M = {}

local function linters(buffer)
    local lint = require "lint"
    return lint.linters_by_ft[vim.bo[buffer].filetype] or {}
end

local function try_lint(buffer)
    local lint = require "lint"

    buffer = buffer or vim.api.nvim_get_current_buf()
    local names = linters(buffer)

    local file_name = vim.api.nvim_buf_get_name(buffer)
    local ctx = {
        filename = file_name,
        dirname = vim.fn.fnamemodify(file_name, ":h"),
        buffer = buffer,
    }

    names = vim.tbl_filter(function(name)
        local linter = lint.linters[name]
        return linter and not (type(linter) == "table" and linter.condition and not linter.condition(ctx))
    end, names)

    if #names > 0 then
        lint.try_lint(names)
    end
end

function M.active_names_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return linters(buffer)
end

function M.active_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return #linters(buffer) > 0
end

M.apply = utils.debounce(100, try_lint)

function M.enabled_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local enabled = vim.b[buffer].linting_enabled
    if enabled == nil or enabled == true then
        return true
    end

    return false
end

function M.toggle_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local enabled = M.enabled_for_buffer(buffer)
    if enabled then
        utils.info("Turning off linting for buffer.")
        vim.b[buffer].linting_enabled = false
    else
        utils.info("Turning on linting for buffer.")
        vim.b[buffer].linting_enabled = true
    end
end

function M.enabled()
    local enabled = vim.g.linting_enabled
    if enabled == nil or enabled == true then
        return true
    end

    return false
end

function M.toggle()
    local enabled = M.enabled()

    if enabled then
        utils.info("Turning off auto-formatting globally.")
        vim.g.linting_enabled = false
    else
        utils.info("Turning on auto-formatting globally.")
        vim.g.linting_enabled = true
    end
end

function M.test()
    local lint = require "lint"
    local def = utils.tbl_merge(lint.linters.golangcilint, { name = "golangcilint" })

    lint.lint(def)
end

return M
