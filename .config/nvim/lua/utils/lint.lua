local utils = require "utils"
local project = require "utils.project"

local M = {}

local function linters(buffer)
    if not package.loaded["lint"] then
        return {}
    end

    local lint = require "lint"
    local linters = vim.api.nvim_buf_is_valid(buffer) and lint.linters_by_ft[vim.bo[buffer].filetype] or {}

    local file_name = vim.api.nvim_buf_get_name(buffer)
    local ctx = {
        filename = file_name,
        dirname = vim.fn.fnamemodify(file_name, ":h"),
        buf = buffer,
    }

    return vim.tbl_filter(function(name)
        local linter = lint.linters[name]
        return linter and not (type(linter) == "table" and linter.condition and not linter.condition(ctx))
    end, linters)
end

local function try_lint(buffer)
    local lint = require "lint"

    buffer = buffer or vim.api.nvim_get_current_buf()

    -- check if we have any linters for this fie type
    local names = linters(buffer)
    if #names == 0 then
        return
    end

    if #names > 0 then
        lint.try_lint(names, { cwd = project.root(buffer) })
    end
end

function M.active_names_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return linters(buffer)
end

function M.active_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local l = linters(buffer)
    print("active linters = ", #l)

    return #linters(buffer) > 0
end

M.apply = utils.debounce(100, try_lint)

function M.enabled_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local enabled = vim.api.nvim_buf_is_valid(buffer) and vim.b[buffer].linting_enabled
    if enabled == nil or enabled == true then
        return true
    end

    return false
end

function M.toggle_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    if not vim.api.nvim_buf_is_valid(buffer) then
        return
    end

    local enabled = M.enabled_for_buffer(buffer)
    if enabled then
        utils.info("Turning off linting for buffer.")
        -- TODO: figure out how to clear them diagnostics
        vim.diagnostic.reset()
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

        vim.diagnostic.reset()
        vim.g.linting_enabled = false
    else
        utils.info("Turning on auto-formatting globally.")
        vim.g.linting_enabled = true
    end
end

return M
