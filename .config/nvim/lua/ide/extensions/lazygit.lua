-- Lazygit extension: terminal UI for git with auto-synced color theme.
-- Replaces legacy lua/lazy-git.lua.

local Extension = require 'ide.Extension'

local Lazygit = Class('Lazygit', Extension)

function Lazygit:init()
    Extension.init(self, 'Lazygit')
    self._config_dir = nil
    self._theme_dirty = true
    self._custom_config_path = vim.fs.normalize(
        IDE.fs:join(IDE.fs:cache_dir(), 'lazy-git-config.json'))
end

local THEME_MAP = {
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

local Highlight = require 'ide.Highlight'

local function resolve_color(entry)
    local hex = '#000000'
    if entry.foreground then
        hex = Highlight.get(entry.foreground):fg_hex() or hex
    elseif entry.background then
        hex = Highlight.get(entry.background):bg_hex() or hex
    end
    return hex, entry.bold and 'bold' or nil, entry.underline and 'underline' or nil
end

function Lazygit:_apply_theme()
    local lg_theme = {}
    for key, entry in pairs(THEME_MAP) do
        if type(key) == 'number' then
            pcall(function()
                local hex = resolve_color(entry)
                io.write(('\27]4;%d;%s\7'):format(key, hex))
            end)
        else
            lg_theme[key] = { resolve_color(entry) }
        end
    end

    local spinner_frames = {}
    if IDE.icons and IDE.icons.progress_frames then
        spinner_frames = IDE.icons:progress_frames()
    else
        spinner_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
    end

    local config = {
        os = { editPreset = 'nvim-remote' },
        gui = {
            nerdFontsVersion = 3,
            theme = lg_theme,
            spinner = { frames = spinner_frames, rate = 100 },
        },
    }

    self._theme_dirty = false
    local json = vim.json.encode(config)
    local ok, err = IDE.fs:write(self._custom_config_path, json)
    if not ok then
        IDE.ui:error('Failed to write lazygit config: ' .. tostring(err))
    end
end

function Lazygit:_ensure_config(callback)
    if not self._config_dir then
        IDE.shell:run('lazygit', { '-cd' }, {}, function(result)
            if result.code == 0 then
                self._config_dir = vim.trim(result.stdout)
                vim.env.LG_CONFIG_FILE = string.format('%s,%s',
                    vim.fs.normalize(vim.fs.joinpath(self._config_dir, 'config.yml')),
                    self._custom_config_path)
            end
            self:_apply_theme()
            callback()
        end)
    else
        if self._theme_dirty then self:_apply_theme() end
        callback()
    end
end

function Lazygit:run()
    self:_ensure_config(function()
        IDE.shell:floating('lazygit')
    end)
end

function Lazygit:on_register(ctx)
    if not IDE.shell:has('lazygit') then return end

    local ext = self

    ctx:command('Lazygit', function() ext:run() end, { desc = 'Run Lazygit' })
    ctx:keymap('n', '<leader>g', function() ext:run() end, { desc = 'Lazygit' })

    ctx:hook('ColorScheme', function()
        ext._theme_dirty = true
    end, { desc = 'Invalidate lazygit theme on colorscheme change' })
end

return Lazygit
