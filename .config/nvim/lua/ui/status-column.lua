local utils = require 'core.utils'
local ui = require 'ui'

--- Gets the icon for a sign
---@param sign ui.Sign | nil # the sign to get the icon for
---@return string # the icon
local function icon(sign)
    sign = sign or {}

    local text = vim.fn.strcharpart(sign.text or '', 0, 2) ---@type string

    text = text .. string.rep(' ', 2 - vim.fn.strchars(text))
    return sign.texthl and ('%#' .. sign.texthl .. '#' .. text .. '%*') or text
end

--- Gets the status column for the current buffer
---@return string # the status column
local function status_column()
    local window = vim.api.nvim_get_var 'statusline_winid'
    local buffer = vim.api.nvim_win_get_buf(window)

    local is_file = utils.is_regular_buffer(buffer)
    local show_signs = vim.api.nvim_get_option_value('signcolumn', { win = window }) ~= 'no'

    local components = { '', '', '' } -- left, middle, right

    if show_signs then
        local ext_marks = ui.get_ext_marks(buffer, vim.v.lnum)

        ---@type ui.Sign | nil, ui.Sign | nil, ui.Sign | nil, string | nil
        local left, right, fold, githl

        for _, s in ipairs(ext_marks) do
            if s.name and (s.name:find 'GitSign') then
                right = s
                githl = s['texthl']
            else
                left = s
            end
        end

        vim.api.nvim_win_call(window, function()
            if vim.fn.foldclosed(vim.v.lnum) >= 0 then
                fold = { text = vim.opt.fillchars:get().foldclose, texthl = githl or 'Folded', priority = 0 }
            elseif tostring(vim.treesitter.foldexpr(vim.v.lnum)):sub(1, 1) == '>' then
                fold = { text = vim.opt.fillchars:get().foldopen, texthl = githl, priority = 0 }
            end
        end)

        components[1] = icon(left)
        components[3] = is_file and icon(fold or right) or ''
    end

    local number_col_enabled = vim.api.nvim_get_option_value('number', { win = window })
    local relative_number_col_enabled = vim.api.nvim_get_option_value('relativenumber', { win = window })

    if (number_col_enabled or relative_number_col_enabled) and vim.v.virtnum == 0 then
        if vim.fn.has 'nvim-0.11' == 1 then
            components[2] = '%l' -- 0.11 handles both the current and other lines with %l
        else
            if vim.v.relnum == 0 then
                components[2] = number_col_enabled and '%l' or '%r'
            else
                components[2] = relative_number_col_enabled and '%r' or '%l'
            end
        end
        components[2] = '%=' .. components[2] .. ' '
    end

    if vim.v.virtnum ~= 0 then
        components[2] = '%= '
    end

    return table.concat(components, '')
end

return status_column
