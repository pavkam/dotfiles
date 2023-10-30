local utils = require "utils"
local lsp = require "utils.lsp"
local project = require "utils.project"
local settings = require "utils.settings"

local M = {}

local setting_name = "auto_linting_enabled"

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

function M.active_names_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return linters(buffer)
end

function M.active_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    return #linters(buffer) > 0
end

function M.apply(buffer, force)
    if not force and (
        not settings.get_global(setting_name, true) or
        not settings.get_permanent_for_buffer(buffer, setting_name, true)
    ) then
        return
    end

    buffer = buffer or vim.api.nvim_get_current_buf()

    -- check if we have any linters for this fie type
    local names = linters(buffer)
    if #names == 0 then
        return
    end

    local lint = require "lint"

    utils.debounce(100, function()
        local do_lint = function()
            lint.try_lint(names, { cwd = project.root(buffer) })
        end

        -- lint current buffer or inside another buffer
        if buffer == vim.api.nvim_get_current_buf() then
            do_lint()
        else
            vim.api.nvim_buf_call(buffer, do_lint)
        end
    end)
end

function M.toggle_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local enabled = settings.get_permanent_for_buffer(buffer, setting_name, true)

    local file_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ":t")

    utils.info(string.format("Turning **%s** auto-linting for *%s*.", enabled and "off" or "on", file_name))
    settings.set_permanent_for_buffer(buffer, setting_name, not enabled)

    if enabled then
        -- clear diagnostics from buffer linters
        lsp.clear_diagnostics(linters(buffer), buffer)
    else
        -- re-lint
        M.apply(buffer)
    end
end

function M.toggle()
    local enabled = settings.get_global(setting_name, true)

    utils.info(string.format("Turning **%s** auto-linting *globally*.", enabled and "off" or "on"))
    settings.set_global(setting_name, not enabled)

    if enabled then
        -- clear diagnostics from all buffers
        for _, buffer in ipairs(utils.get_listed_buffers()) do
            lsp.clear_diagnostics(linters(buffer), buffer)
        end
    else
        -- re-lint
        for _, buffer in ipairs(utils.get_listed_buffers()) do
            M.apply(buffer)
        end
    end
end

return M
