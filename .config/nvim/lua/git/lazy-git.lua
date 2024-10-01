local events = require 'core.events'
local shell = require 'core.shell'

---@class (exact) git.lazy-git.Color # A color for lazy-git.
---@field foreground string|nil # the foreground color.
---@field background string|nil # the background color.
---@field bold boolean|nil # whether the text is bold.
---@field underline boolean|nil # whether the text is underlined.
---@field strikethrough boolean|nil # whether the text is strikethrough.

---@type table<number|string, git.lazy-git.Color>
local theme = {
    [241] = { foreground = 'Special' },
    activeBorderColor = { foreground = 'MatchParen', bold = true },
    cherryPickedCommitBgColor = { foreground = 'Identifier' },
    cherryPickedCommitFgColor = { foreground = 'Function' },
    defaultFgColor = { foreground = 'Normal' },
    inactiveBorderColor = { foreground = 'FloatBorder' },
    optionsTextColor = { foreground = 'Function' },
    searchingActiveBorderColor = { foreground = 'MatchParen', bold = true },
    selectedLineBgColor = { background = 'Visual' },
    unstagedChangesColor = { foreground = 'DiagnosticError' },
}

---@type string
local command = 'lazygit'
---@type string
local custom_config_path = vim.fs.normalize(vim.fs.joinpath(vim.fs.cache_dir, 'lazy-git-config.json'))
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
---@return string, string|nil, string|nil, string|nil # The color, bold, underline, and strikethrough.
local function deconstruct_color(color)
    local numeric = 0
    if color.foreground then
        local hl = vim.api.nvim_get_hl(0, { name = color.foreground, link = false })
        numeric = hl.fg
    elseif color.background then
        local hl = vim.api.nvim_get_hl(0, { name = color.background, link = false })
        numeric = hl.bg
    end

    local bold = color.bold and 'bold' or nil
    local underline = color.underline and 'underline' or nil
    local strikethrough = color.strikethrough and 'strikethrough' or nil

    return string.format('#%06x', numeric), bold, underline, strikethrough
end

--- Runs a function with the updated color theme for lazy git.
---@param done_fn function # the function to call when the update is finished.
local function with_updated_color_theme(done_fn)
    assert(type(done_fn) == 'function')

    local function apply()
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

        local json = vim.json.encode(config)

        local ok, err = vim.fs.write_text_file(custom_config_path, json)
        if not ok then
            vim.error(
                string.format(
                    'Failed to apply custom Lazygit theme at `%s`\nError was: %s.',
                    custom_config_path,
                    vim.inspect(err)
                )
            )
        end
    end

    if not config_dir then
        shell.async_cmd(command, { '-cd' }, nil, function(output)
            config_dir = output[1]

            vim.env.LG_CONFIG_FILE =
                string.format('%s,%s', vim.fs.normalize(vim.fs.joinpath(config_dir, 'config.yml')), custom_config_path)

            apply()
            done_fn()
        end)
    else
        if color_theme_needs_update then
            apply()
        end

        done_fn()
    end
end

events.on_event('ColorScheme', function()
    color_theme_needs_update = true
end)

--- Runs lazygit with the updated color theme.
local function run_lazygit()
    with_updated_color_theme(function()
        shell.floating(command)
    end)
end

-- Add a command to run lazygit
if vim.fn.executable(command) == 1 then
    require('core.commands').register_command('Lazygit', function()
        run_lazygit()
    end, { desc = 'Run Lazygit', nargs = 0 })

    require('core.keys').map('n', '<leader>g', function()
        vim.cmd 'Lazygit'
    end, { icon = require('ui.icons').UI.Git, desc = 'Lazygit' })
end

return run_lazygit
