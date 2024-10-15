---@module 'ui.bars'

local icons = require 'ui.icons'
local hl = require 'ui.hl'

---@class ui.bars.components
local M = {}

local tokyonight_colors = require('tokyonight.colors').setup()

local highlights = {
    -- Bar component colors
    BarComponentModeNormal = { fg = tokyonight_colors.blue, bold = true },
    BarComponentModeInsert = { fg = tokyonight_colors.green, bold = true },
    BarComponentModeVisual = { fg = tokyonight_colors.magenta, bold = true },
    BarComponentModeReplace = { fg = tokyonight_colors.red, bold = true },
    BarComponentModeCommand = { fg = tokyonight_colors.yellow, bold = true },

    BarComponentSpecial = { fg = tokyonight_colors.fg_sidebar, bold = true },
}

hl.make_hls(highlights)

---@type table<string, string[]>
local mode_mapping = {
    ['n'] = { 'NORMAL', 'Normal' },
    ['no'] = { 'OP-PENDING', 'Normal' },
    ['nov'] = { 'OP-PENDING', 'Normal' },
    ['noV'] = { 'OP-PENDING', 'Normal' },
    ['no\22'] = { 'OP-PENDING', 'Normal' },
    ['niI'] = { 'NORMAL', 'Normal' },
    ['niR'] = { 'NORMAL', 'Normal' },
    ['niV'] = { 'NORMAL', 'Normal' },
    ['nt'] = { 'NORMAL', 'Normal' },
    ['ntT'] = { 'NORMAL', 'Normal' },
    ['v'] = { 'VISUAL', 'Visual' },
    ['vs'] = { 'VISUAL', 'Visual' },
    ['V'] = { 'VISUAL', 'Visual' },
    ['Vs'] = { 'VISUAL', 'Visual' },
    ['\22'] = { 'VISUAL', 'Visual' },
    ['\22s'] = { 'VISUAL', 'Visual' },
    ['s'] = { 'SELECT', 'Visual' },
    ['S'] = { 'SELECT', 'Visual' },
    ['\19'] = { 'SELECT', 'Visual' },
    ['i'] = { 'INSERT', 'Insert' },
    ['ic'] = { 'INSERT', 'Insert' },
    ['ix'] = { 'INSERT', 'Insert' },
    ['R'] = { 'REPLACE', 'Replace' },
    ['Rc'] = { 'REPLACE', 'Replace' },
    ['Rx'] = { 'REPLACE', 'Replace' },
    ['Rv'] = { 'VIRT REPLACE', 'Replace' },
    ['Rvc'] = { 'VIRT REPLACE', 'Replace' },
    ['Rvx'] = { 'VIRT REPLACE', 'Replace' },
    ['c'] = { 'COMMAND', 'Command' },
    ['cv'] = { 'VIM EX', 'Command' },
    ['ce'] = { 'EX', 'Command' },
    ['r'] = { 'PROMPT', 'Command' },
    ['rm'] = { 'MORE', 'Command' },
    ['r?'] = { 'CONFIRM', 'Command' },
    ['!'] = { 'SHELL', 'Terminal' },
    ['t'] = { 'TERMINAL', 'Terminal' },
}

-- Gets the current mode details for display.
---@return string, string # the mode name and the highlight group.
local function get_mode_details()
    local mode = mode_mapping[vim.api.nvim_get_mode().mode]
    if not mode then
        mode = { 'UNKNOWN', 'Normal' }
    end

    local name, hl_suffix = unpack(mode)

    return name, 'BarComponentMode' .. hl_suffix
end

--- Creates a new 'buffer name' component.
---@return ui.bars.Component # the component.
function M.buffer_name()
    local project = require 'project'

    ---@type ui.bars.Component
    return {
        align = 'fit',
        min_width = 10,
        render = function(context, max_width)
            assert(context.buffer)

            local _, mode_hl_group = get_mode_details()

            if vim.buf.is_regular(context.buffer) or context.buffer_type == 'help' then
                local name = context.name
                local icon, hl_group = icons.get_file_icon(name, 2)

                if context.buffer_type == 'help' then
                    icon = icons.fit(icons.UI.Help, 2)
                end

                max_width = max_width - vim.fn.strwidth(icon)

                local root = project.root(context.buffer, false)
                if name == '' then
                    name = '[No Name]'
                elseif root then
                    name = vim.fs.format_relative_path(root, name, { include_base_dir = true, max_width = max_width })
                end

                return {
                    { text = icon, hl_group = context.active and hl_group or nil },
                    {
                        text = vim.abbreviate(name, { max = max_width }),
                        hl_group = context.active and mode_hl_group or nil,
                    },
                }
            else
                local name = context.name
                if name == '' then
                    name = vim.api.nvim_get_option_value('filetype', { buf = context.buffer })
                end
                if name == '' then
                    name = context.buffer_type
                end
                if name == '' then
                    name = '[Unknown]'
                end

                ---@type string
                local icon

                -- TODO: move this mapping to the icons module
                if context.window_type == 'quick-fix' or context.window_type == 'location-list' then
                    icon = icons.fit(icons.UI.Fix, 2)
                elseif vim.startswith(context.file_type, 'dap-') or vim.startswith(context.file_type, 'dapui_') then
                    icon = icons.fit(icons.UI.Debugger, 2)
                elseif vim.startswith(context.file_type, 'neotest-') then
                    icon = icons.fit(icons.UI.Test, 2)
                else
                    icon = icons.fit(icons.UI.Tool, 2)
                end

                max_width = max_width - vim.fn.strwidth(icon)

                return {
                    { text = icon, hl_group = context.active and 'BarComponentSpecial' or nil },
                    {
                        text = vim.abbreviate(name, { max = max_width }),
                        hl_group = context.active and 'BarComponentSpecial' or nil,
                    },
                }
            end
        end,
    }
end

--- Creates a new 'fill empty space' component.
---@return ui.bars.Component # the component.
function M.fill()
    ---@type ui.bars.Component
    return {
        align = 'left',
        render = function()
            return ''
        end,
    }
end

return M
