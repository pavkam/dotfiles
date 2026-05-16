-- IconDB: file icon database.
-- Core IDE class — provides icon lookup for files, filetypes, and tools.
-- Returns Icon toolkit objects with proper highlight groups.
-- Replaces nvim-web-devicons entirely.

local Icon = require 'ide.toolkit.Icon'

local IconDB = Class('IconDB')

function IconDB:init()
    self._by_extension = nil
    self._by_filename = nil
    self._hl_defined = {}
end

function IconDB:_load()
    if self._by_extension then return end

    local base = vim.fs.joinpath(vim.fn.stdpath('config'), 'lua', 'ide', 'extensions')
    self._by_extension = dofile(vim.fs.joinpath(base, 'file_icons_by_extension.lua')) or {}
    self._by_filename = dofile(vim.fs.joinpath(base, 'file_icons_by_filename.lua')) or {}

    self:_apply_overrides()
    self:_register_shim()
    self:_register_symbol_provider()
end

function IconDB:_ensure_hl(name, color)
    if self._hl_defined[name] then return end
    require('ide.Highlight')(name):fg(color):as_default():define()
    self._hl_defined[name] = true
end

function IconDB:_apply_overrides()
    local overrides = {
        deb = { icon = '', color = '#a1b7ee', name = 'Deb' },
        lock = { icon = '󰌾', color = '#bbbbbb', name = 'Lock' },
        mp3 = { icon = '󰎆', color = '#00afff', name = 'Mp3' },
        mp4 = { icon = '', color = '#FD971F', name = 'Mp4' },
        out = { icon = '', color = '#abb2bf', name = 'Out' },
        ttf = { icon = '', color = '#abb2bf', name = 'TrueTypeFont' },
        rpm = { icon = '', color = '#fca2aa', name = 'Rpm' },
        woff = { icon = '', color = '#abb2bf', name = 'WebOpenFontFormat' },
        woff2 = { icon = '', color = '#abb2bf', name = 'WebOpenFontFormat2' },
        xz = { icon = '', color = '#ECA517', name = 'Xz' },
        zip = { icon = '', color = '#ECA517', name = 'Zip' },
    }
    for ext, entry in pairs(overrides) do
        self._by_extension[ext] = entry
    end
    self._by_filename['robots.txt'] = { icon = '󰚩', color = '#5d7096', name = 'Robots' }
end

--- Look up an icon by filename and/or extension.
---@param filename string|nil
---@param extension string|nil
---@param opts { default?: boolean }|nil
---@return Icon
function IconDB:for_file(filename, extension, opts)
    self:_load()
    opts = opts or {}

    local entry = nil

    if filename then
        entry = self._by_filename[filename]
    end

    if not entry and extension then
        entry = self._by_extension[extension]
    end

    if not entry and filename then
        local ext = filename:match('%.([^%.]+)$') or filename
        entry = self._by_extension[ext]
    end

    if entry then
        local hl = 'DevIcon' .. entry.name
        self:_ensure_hl(hl, entry.color)
        return Icon(entry.icon, hl, entry.name)
    end

    if opts.default ~= false then
        self:_ensure_hl('DevIconDefault', '#6d8086')
        return Icon.default()
    end

    return Icon('', 'Normal')
end

--- Look up an icon by filetype.
---@param filetype string
---@return Icon
function IconDB:for_filetype(filetype)
    self:_load()
    local entry = self._by_extension[filetype]
    if entry then
        local hl = 'DevIcon' .. entry.name
        self:_ensure_hl(hl, entry.color)
        return Icon(entry.icon, hl, entry.name)
    end
    return Icon.default()
end

--- Register as nvim-web-devicons shim for plugin compatibility.
function IconDB:_register_shim()
    local db = self
    package.loaded['nvim-web-devicons'] = {
        get_icon = function(name, ext, opts)
            local icon = db:for_file(name, ext, opts)
            return icon:char(), icon:hl()
        end,
        get_icon_by_filetype = function(ft)
            local icon = db:for_filetype(ft)
            return icon:char(), icon:hl()
        end,
        has_loaded = function() return db._by_extension ~= nil end,
        setup = function() end,
    }
end

function IconDB:_register_symbol_provider()
    local ok, plugin_mod = pcall(require, 'plugin')
    if not ok or not plugin_mod.symbol_provider then return end
    local db = self
    plugin_mod.symbol_provider.register {
        get_file_symbol = function(path)
            if type(path) ~= 'string' or path == '' then return '' end
            if _G.IDE and IDE.fs:is_directory(path) then return '' end
            local icon = db:for_file(vim.fs.basename(path), nil, { default = true })
            local hl = icon:hl()
            return hl and { icon:char(), hl = hl } or icon:char()
        end,
        get_file_type_symbol = function(file_type)
            if type(file_type) ~= 'string' or file_type == '' then return '' end
            local icon = db:for_filetype(file_type)
            local hl = icon:hl()
            return hl and { icon:char(), hl = hl } or icon:char()
        end,
    }
end

---@return boolean
function IconDB:is_loaded()
    return self._by_extension ~= nil
end

---@return string
function IconDB:__tostring()
    return 'IconDB()'
end

return IconDB
