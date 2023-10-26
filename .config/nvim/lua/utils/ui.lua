-- general UI functionality
local icons = require 'utils.icons'
local utils = require 'utils'

M = {}

M.attach_q_key_file_types = {
    "neo-tree",
    "dap-float",
    "dap-repl",
    "dapui_console",
    "dapui_watches",
    "dapui_stacks",
    "dapui_breakpoints",
    "dapui_scopes",
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
}

M.special_file_types = vim.list_extend(
    utils.tbl_copy(M.attach_q_key_file_types),
    {
        "WhichKey",
        "TelescopePrompt",
        "TelescopeResults",
    }
)

M.special_buffer_types = {
    "prompt",
    "nofile",
    "terminal",
    "help",
}

function M.is_special_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local filetype = vim.api.nvim_get_option_value("filetype", { buf = buffer })
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buffer })

    return (
        vim.tbl_contains(M.special_buffer_types, buftype) or
        vim.tbl_contains(M.special_file_types, filetype)
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

function M.cursor_word_relation(window)
    window = window or 0

    -- get the cursor's position
    local r, c = unpack(vim.api.nvim_win_get_cursor(window))
    if not c or not r then
        return false
    end

    local line = vim.api.nvim_buf_get_lines(vim.fn.winbufnr(window), r - 1, r, true)[1]

    local before = string.sub(line, 1, c)
    local after = string.sub(line, c + 1, -1)

    return string.match(before, "^%s*$") == nil, string.match(after, "^%s*$") == nil
end

return M
