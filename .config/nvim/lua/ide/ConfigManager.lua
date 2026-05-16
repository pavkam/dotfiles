-- ConfigManager: settings and toggle management.
-- Wraps vim.g/vim.b with persistence and toggle tracking.

local EventEmitter = require 'ide.EventEmitter'

local ConfigManager = Class('ConfigManager')
Class.include(ConfigManager, EventEmitter)

function ConfigManager:init()
    self._toggles = {} ---@type table<string, { value: boolean, desc: string, scope: string }>
end

--- Get a global setting.
---@param name string
---@param default any
---@return any
function ConfigManager:get(name, default)
    local val = vim.g[name]
    return val ~= nil and val or default
end

--- Set a global setting.
---@param name string
---@param value any
function ConfigManager:set(name, value)
    vim.g[name] = value
    self:emit('change', name, value)
end

--- Get a buffer-local setting.
---@param bufnr integer
---@param name string
---@param default any
---@return any
function ConfigManager:buf_get(bufnr, name, default)
    local val = vim.b[bufnr][name]
    return val ~= nil and val or default
end

--- Set a buffer-local setting.
---@param bufnr integer
---@param name string
---@param value any
function ConfigManager:buf_set(bufnr, name, value)
    vim.b[bufnr][name] = value
    self:emit('buf_change', bufnr, name, value)
end

--- Get a global editor option (vim.o).
---@param name string
---@return any
function ConfigManager:option(name)
    return vim.o[name]
end

--- Set a global editor option (vim.o).
---@param name string
---@param value any
function ConfigManager:set_option(name, value)
    vim.o[name] = value
end

--- Register a toggle setting.
---@param name string
---@param opts { desc?: string, default?: boolean, scope?: string, on_toggle?: fun(enabled: boolean) }|nil
---@return ConfigManager
function ConfigManager:register_toggle(name, opts)
    opts = opts or {}
    self._toggles[name] = {
        value = opts.default ~= false,
        desc = opts.desc or name,
        scope = opts.scope or 'global',
        on_toggle = opts.on_toggle,
    }
    return self
end

--- Unregister a toggle setting (for cleanup/testing).
---@param name string
function ConfigManager:unregister_toggle(name)
    self._toggles[name] = nil
end

--- Toggle a setting on/off.
---@param name string
---@return boolean # new value
function ConfigManager:toggle(name)
    local t = self._toggles[name]
    if not t then return false end
    t.value = not t.value
    if t.on_toggle then
        pcall(t.on_toggle, t.value)
    end
    self:emit('toggle', name, t.value)
    self:save()
    return t.value
end

--- Get toggle value.
---@param name string
---@return boolean
function ConfigManager:is_enabled(name)
    local t = self._toggles[name]
    return t and t.value or false
end

--- Get all toggles for display.
---@return table[]
function ConfigManager:toggles()
    local result = {}
    for name, t in pairs(self._toggles) do
        table.insert(result, {
            name = name,
            desc = t.desc,
            value = t.value,
            scope = t.scope,
        })
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

--- Use a buffer-local option (get/set pair).
--- Replaces old ide.config.use() for per-buffer state tracking.
---@param bufnr integer
---@param name string
---@param default any
---@return { get: fun(d?: any): any, set: fun(v: any) }
function ConfigManager:use(bufnr, name, default)
    return {
        get = function(d)
            local val = vim.b[bufnr][name]
            if val ~= nil then return val end
            return d ~= nil and d or default
        end,
        set = function(value)
            if vim.api.nvim_buf_is_valid(bufnr) then
                vim.b[bufnr][name] = value
                self:emit('buf_change', bufnr, name, value)
            end
        end,
    }
end

--- Get the settings file path.
---@return string
function ConfigManager:settings_path()
    return vim.fs.joinpath(vim.fn.stdpath('config'), 'ide-settings.json')
end

--- Get the project-local settings file path.
---@return string|nil
function ConfigManager:project_settings_path()
    if not _G.IDE then return nil end
    local proj = IDE:project()
    if not proj then return nil end
    return vim.fs.joinpath(proj:root(), '.ide-settings.json')
end

--- Save all settings to disk.
function ConfigManager:save()
    local data = { toggles = {} }
    for name, t in pairs(self._toggles) do
        data.toggles[name] = t.value
    end
    local json = vim.json.encode(data)
    local path = self:settings_path()
    local f = io.open(path, 'w')
    if f then
        f:write(json)
        f:close()
    end
end

--- Load settings from disk. Merges project-local overrides if present.
function ConfigManager:load()
    self:_load_file(self:settings_path())
    local proj_path = self:project_settings_path()
    if proj_path then
        self:_load_file(proj_path)
    end
end

---@param path string
function ConfigManager:_load_file(path)
    local f = io.open(path, 'r')
    if not f then return end
    local content = f:read('*a')
    f:close()
    local ok, data = pcall(vim.json.decode, content)
    if not ok or type(data) ~= 'table' then return end
    if data.toggles then
        for name, value in pairs(data.toggles) do
            local t = self._toggles[name]
            if t and type(value) == 'boolean' then
                t.value = value
                if t.on_toggle then pcall(t.on_toggle, value) end
            end
        end
    end
    self:emit('loaded', path)
end

--- Export persistent config data for session save.
---@return table
function ConfigManager:export()
    local data = { toggles = {} }
    for name, t in pairs(self._toggles) do
        data.toggles[name] = t.value
    end
    return data
end

--- Import persistent config data from session restore.
---@param data table
function ConfigManager:import(data)
    if not data or not data.toggles then return end
    for name, value in pairs(data.toggles) do
        local t = self._toggles[name]
        if t and type(value) == 'boolean' then
            t.value = value
            if t.on_toggle then pcall(t.on_toggle, value) end
        end
    end
end

--- Show the toggle management UI as a TurboVision dialog.
function ConfigManager:manage()
    local Dialog = require 'ide.toolkit.Dialog'
    local Checkbox = require 'ide.toolkit.Checkbox'
    local Button = require 'ide.toolkit.Button'

    local toggles = self:toggles()
    local cfg = self

    -- Group toggles by category
    local groups = {
        { name = '── Editor ──', items = {} },
        { name = '── LSP ──', items = {} },
        { name = '── Theme ──', items = {} },
    }

    local editor_keys = { 'auto_formatting', 'auto_linting', 'spell_checking', 'treesitter_highlighting' }
    local lsp_keys = { 'code_lens', 'diagnostics_enabled', 'inlay_hints', 'semantic_tokens' }

    for _, t in ipairs(toggles) do
        local placed = false
        for _, k in ipairs(editor_keys) do
            if t.name == k then groups[1].items[#groups[1].items + 1] = t; placed = true; break end
        end
        if not placed then
            for _, k in ipairs(lsp_keys) do
                if t.name == k then groups[2].items[#groups[2].items + 1] = t; placed = true; break end
            end
        end
        if not placed then
            groups[3].items[#groups[3].items + 1] = t
        end
    end

    -- Calculate size
    local max_label = 0
    for _, t in ipairs(toggles) do
        local label = t.desc or t.name
        if #label > max_label then max_label = #label end
    end
    local width = math.max(max_label + 8, 36)
    local row = 1
    local total_rows = 0
    for _, g in ipairs(groups) do
        if #g.items > 0 then total_rows = total_rows + #g.items + 2 end -- header + items + spacer
    end
    local height = total_rows + 3

    local dlg = Dialog({
        title = '&Options',
        width = width,
        height = height,
        shadow = true,
    })

    -- Add grouped checkboxes
    for _, g in ipairs(groups) do
        if #g.items > 0 then
            row = row + 1
            for _, t in ipairs(g.items) do
                local label = t.desc or t.name
                dlg:add_widget(Checkbox({
                    label = label,
                    checked = t.value,
                    on_change = function(checked)
                        if cfg:is_enabled(t.name) ~= checked then
                            cfg:toggle(t.name)
                        end
                    end,
                }), row, 2)
                row = row + 1
            end
            row = row + 1
        end
    end

    -- Buffer settings section
    local ComboBox = require 'ide.toolkit.ComboBox'
    local Buffer = require 'ide.Buffer'
    local buf = Buffer.current()
    if buf:is_valid() and buf:is_normal() then
        row = row + 1
        dlg:add_widget(ComboBox({
            label = '&Tab Width',
            options = { '2', '4', '8' },
            selected = ({ ['2'] = 1, ['4'] = 2, ['8'] = 3 })[tostring(buf:option('tabstop'))] or 2,
            on_change = function(val)
                local n = tonumber(val)
                if n then
                    buf:set_option('tabstop', n)
                    buf:set_option('shiftwidth', n)
                end
            end,
        }), row, 2)
        row = row + 1
        dlg:add_widget(ComboBox({
            label = '&Indent',
            options = { 'Spaces', 'Tabs' },
            selected = buf:option('expandtab') and 1 or 2,
            on_change = function(val)
                buf:set_option('expandtab', val == 'Spaces')
            end,
        }), row, 2)
    end

    -- OK + Cancel buttons
    row = row + 2
    local btn_row = row
    dlg:add_widget(Button({
        label = '&OK',
        style = 'primary',
        action = function() dlg:close() end,
    }), btn_row, math.floor(width / 2) - 8)

    dlg:add_widget(Button({
        label = '&Cancel',
        action = function() dlg:close() end,
    }), btn_row, math.floor(width / 2) + 2)

    dlg:show()
end

---@return string
function ConfigManager:__tostring()
    return string.format('ConfigManager(%d toggles)', vim.tbl_count(self._toggles))
end

return ConfigManager
