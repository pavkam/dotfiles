local events = require 'core.events'
local shell = require 'core.shell'

---@class (exact) git.lazy-git.Color # A color for lazy-git.
---@field fg string|nil # the foreground color.
---@field bg string|nil # the background color.
---@field bold boolean|nil # whether the color is bold.

---@type table<number|string, git.lazy-git.Color>
local theme = {
    [241] = { fg = 'Special' },
    activeBorderColor = { fg = 'MatchParen', bold = true },
    cherryPickedCommitBgColor = { fg = 'Identifier' },
    cherryPickedCommitFgColor = { fg = 'Function' },
    defaultFgColor = { fg = 'Normal' },
    inactiveBorderColor = { fg = 'FloatBorder' },
    optionsTextColor = { fg = 'Function' },
    searchingActiveBorderColor = { fg = 'MatchParen', bold = true },
    selectedLineBgColor = { bg = 'Visual' },
    unstagedChangesColor = { fg = 'DiagnosticError' },
}

---@type string
local command = 'lazygit'
---@type string
local custom_config_path = vim.fs.normalize(vim.fs.joinpath(vim.fs.cache_dir, 'custom-nvim.yml'))
---@type string|nil
local config_dir
local color_theme_needs_update = true

--- Set the ANSI color for a specific index.
---@param color_key number # The index of the color to set.
---@param color string # the color to set.
local function set_ansi_color(color_key, color)
    assert(type(color_key) == 'number')
    assert(type(color) == 'string')

    io.write(('\27]4;%d;%s\7'):format(color_key, color))
end

--- Deconstruct a color to its components.
---@param color git.lazy-git.Color # The color to deconstruct.
local function deconstruct_color(color)
    local hl = assert(vim.api.nvim_get_hl(0, { name = color.fg or color.bg, link = false }))
    return string.format('#%06x', color.fg and hl.fg or hl.bg or 0), color.bold
end

local function update_color_theme()
    if not config_dir then
        shell.async_cmd(command, { '-cd' }, nil, function(output)
            config_dir = output[1]

            vim.env.LG_CONFIG_FILE =
                string.format('%s,%s', vim.fs.normalize(vim.fs.joinpath(config_dir, 'config.yml')), custom_config_path)
        end)
    end

    ---@type table<string, string[]>
    local lazy_git_theme = {}

    for colorKey, color in pairs(theme) do
        if type(colorKey) == 'number' then
            pcall(set_ansi_color, colorKey, deconstruct_color(color))
        else
            lazy_git_theme[colorKey] = { deconstruct_color(color) }
        end
    end

    local config = {
        os = {
            editPreset = 'nvim-remote',
        },
        gui = {
            nerdFontsVersion = 3,
            theme = lazy_git_theme,
        },
    }

    color_theme_needs_update = false

    vim.fn.writefile({ dbg(vim.yaml.encode(config)) }, custom_config_path)
end

events.on_event('ColorScheme', function()
    color_theme_needs_update = true
end)

return function()
    if color_theme_needs_update then
        update_color_theme()
    end

    shell.floating(command)
end
