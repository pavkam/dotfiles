-- general UI functionality
local icons = require 'utils.icons'
local utils = require 'utils'

M = {}

M.special_buffer_file_types = {
    "neo-tree",
    "PlenaryTestPopup",
    "help",
    "lspinfo",
    "man",
    "notify",
    "noice",
    "Outline",
    "qf",
    "query",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "checkhealth",
    "Trouble",
    "terminal",
    "neotest-summary",
    "neotest-output",
    "neotest-output-panel",
    "WhichKey",
    "TelescopePrompt",
    "TelescopeResults",
}

local special_buffer_types = {
    "prompt",
    "nofile",
}

function M.is_special_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local filetype = vim.api.nvim_get_option_value("filetype", { buf = buffer })
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buffer })

    return (
        filetype == "" or
        vim.tbl_contains(special_buffer_types, buftype) or
        vim.tbl_contains(M.special_buffer_file_types, filetype)
    )
end

function M.fold_text()
    local ok = pcall(vim.treesitter.get_parser, vim.api.nvim_get_current_buf())
    local ret = ok and vim.treesitter.foldtext and vim.treesitter.foldtext()
    if not ret then
        ret = {
            {
                vim.api.nvim_buf_get_lines(0, vim.v.lnum - 1, vim.v.lnum, false)[1], {}
            }
        }
    end

    table.insert(ret, { " " .. icons.TUI.Ellipsis })
    return ret
end

function M.hl_fg_color(name)
    local hl = vim.api.nvim_get_hl and vim.api.nvim_get_hl(0, { name = name, link = false }) or vim.api.nvim_get_hl_by_name(name, true)
    local fg = hl and hl.fg or hl.foreground

    return fg and { fg = string.format("#%06x", fg) }
end

function M.sexy_list(list, prefix, separator)
    separator = separator or icons.TUI.ListSeparator
    return prefix .. " " .. utils.tbl_join(list, " " .. separator .. " ")
end

return M
