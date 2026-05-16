-- Status Column Extension: custom gutter rendering with signs, line numbers, and folds.
-- Replaces legacy lua/status-column.lua.

local Extension = require 'ide.Extension'
local Window = require 'ide.Window'
local Buffer = require 'ide.Buffer'
local Dispatch = require 'ide.Dispatch'

local StatusColumn = Class('StatusColumn', Extension)

function StatusColumn:init()
    Extension.init(self, 'StatusColumn')
end

local function format_sign(sign)
    sign = sign or {}
    local text = vim.fn.strcharpart(sign.text or '', 0, 2)
    text = text .. string.rep(' ', 2 - vim.fn.strchars(text))
    return sign.texthl and ('%#' .. sign.texthl .. '#' .. text .. '%*') or text
end

local function get_ext_marks(bufnr, lnum)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local marks = vim.api.nvim_buf_get_extmarks(
        bufnr, -1, { lnum - 1, 0 }, { lnum - 1, -1 }, { details = true, type = 'sign' })
    local result = {}
    for _, m in ipairs(marks) do
        result[#result + 1] = {
            name = m[4].sign_name or m[4].sign_hl_group or '',
            text = m[4].sign_text,
            texthl = m[4].sign_hl_group,
            priority = m[4].priority,
        }
    end
    table.sort(result, function(a, b) return (a.priority or 0) < (b.priority or 0) end)
    return result
end

local function render_status_column()
    local win_id = vim.api.nvim_get_var('statusline_winid')
    if not Window.is_valid(win_id) then return '' end

    local win = Window(win_id)
    local buf = win:buffer()
    local is_file = buf:is_normal()
    local show_signs = win:option('signcolumn') ~= 'no'

    local components = { '', '', '' }

    if show_signs then
        local marks = get_ext_marks(buf:id(), vim.v.lnum)
        local left, right, fold, githl

        for _, s in ipairs(marks) do
            if s.name and s.name:find('GitSign') then
                right = s
                githl = s.texthl
            else
                left = s
            end
        end

        local is_folded = win:is_folded(vim.v.lnum)
        if is_folded then
            fold = { text = vim.opt.fillchars:get().foldclose, texthl = githl or 'Folded', priority = 0 }
        elseif is_folded ~= nil then
            fold = { text = vim.opt.fillchars:get().foldopen, texthl = githl, priority = 0 }
        end

        components[1] = format_sign(left)
        components[3] = is_file and format_sign(fold or right) or ''
    end

    if (win:option('number') or win:option('relativenumber')) and vim.v.virtnum == 0 then
        components[2] = '%=%l '
    end
    if vim.v.virtnum ~= 0 then
        components[2] = '%= '
    end

    return table.concat(components, '')
end

function StatusColumn:on_register(ctx)
    -- Register the render function globally
    Dispatch.renderer('statuscol', render_status_column)
    IDE.config:set_option('statuscolumn', '%!v:lua.IDE_render_statuscol()')

    -- Gutter mouse click handler
    ctx:keymap('n', '<LeftMouse>', function()
        local win_id = vim.api.nvim_get_current_win()
        if not Window.is_valid(win_id) then return '<LeftMouse>' end

        local win = Window(win_id)
        local pos = vim.fn.getmousepos()
        local width = win:status_column_width()

        if pos.wincol > width then return '<LeftMouse>' end

        local marks = get_ext_marks(nil, pos.line)

        -- Git sign click
        if pos.wincol >= width - 1 then
            local has_git = vim.iter(marks):any(function(s)
                return s.name and s.name:match('^GitSign') ~= nil or false
            end)
            if has_git then
                vim.schedule(function()
                    pcall(vim.api.nvim_win_set_cursor, win:id(), { pos.line, 0 })
                    IDE.git:preview_hunk()
                end)
                return
            end
        end

        -- Sign click
        local clicked_char = vim.fn.screenstring(pos.screenrow, pos.screencol)
        clicked_char = clicked_char == ' ' and vim.fn.screenstring(pos.screenrow, pos.screencol - 1) or clicked_char

        local clicked_sign = vim.iter(marks):find(function(s)
            return s.text:gsub('%s', '') == clicked_char
        end)

        if clicked_sign then
            if clicked_sign.name:match('^DiagnosticSign') then
                vim.schedule(function()
                    win:invoke_on_line(vim.diagnostic.open_float, pos.line)
                end)
                return
            end
            if clicked_sign.name == 'DapBreakpoint' then
                win:invoke_on_line(require('dap').toggle_breakpoint, pos.line)
                return
            end
            if clicked_sign.name:match('^mark_') then return end
            return
        elseif pos.wincol <= 2 and pcall(require, 'dap') then
            win:invoke_on_line(require('dap').toggle_breakpoint, pos.line)
            return
        end

        -- Fold toggle
        if win:is_folded(pos.line) ~= nil then
            win:toggle_fold(pos.line)
        end
    end, { expr = true, desc = 'Status column click' })
end

return StatusColumn
