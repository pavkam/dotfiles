-- Dispatch: centralized global callback registry.
-- Consolidates all _G.* callbacks into one namespace.
-- Neovim's statusline/tabline/winbar require global Lua functions
-- for %!v:lua.X() render expressions. This module owns all of them.

local Dispatch = {}

--- Render function registry. These are v:lua-callable global functions.
---@type table<string, function>
Dispatch._renderers = {}

--- Click handler registry (used by StatusBar.click via IDE_click_dispatch).
---@type table<string, function>
Dispatch._click_handlers = {}

--- Register a render function that will be available as v:lua.IDE_render_NAME().
---@param name string
---@param fn function
--- Legacy name mapping for backward compatibility during bytecode cache transitions.
local _legacy_names = {
    global_stl = 'IDE_global_stl',
    statusbar = 'IDE_statusbar_render',
    tabbar = 'IDE_tabbar_render',
    winbar = 'IDE_winbar_render',
    menubar = 'IDE_menubar_render',
}

function Dispatch.renderer(name, fn)
    Dispatch._renderers[name] = fn
    _G['IDE_render_' .. name] = fn
    -- Also register legacy name for bytecode cache compatibility
    if _legacy_names[name] then
        _G[_legacy_names[name]] = fn
    end
end

--- Remove a renderer and its global function.
---@param name string
function Dispatch.remove_renderer(name)
    Dispatch._renderers[name] = nil
    _G['IDE_render_' .. name] = nil
    if _legacy_names[name] then
        _G[_legacy_names[name]] = nil
    end
end

--- Register a click handler.
---@param id string
---@param fn function
function Dispatch.click(id, fn)
    Dispatch._click_handlers[id] = fn
end

--- Remove a click handler.
---@param id string
function Dispatch.remove_click(id)
    Dispatch._click_handlers[id] = nil
end

--- Get a click handler by ID.
---@param id string
---@return function|nil
function Dispatch.get_click(id)
    return Dispatch._click_handlers[id]
end

--- The single global click dispatch function.
_G.IDE_click_dispatch = function(id, ...)
    local handler = Dispatch._click_handlers[id]
    if handler then handler(...) end
end

--- Set up VimScript functions that Neovim requires for statusline clicks.
--- These are thin wrappers that call v:lua Lua functions.
local _vim_funcs_created = false
function Dispatch.ensure_vim_functions()
    if _vim_funcs_created then return end
    _vim_funcs_created = true
    pcall(vim.api.nvim_exec2, [[
        function! IDE_frame_close(minwid, clicks, button, mods)
            call v:lua.IDE_frame_close_lua(a:minwid)
        endfunction
        function! IDE_frame_maximize(minwid, clicks, button, mods)
            call v:lua.IDE_frame_maximize_lua(a:minwid)
        endfunction
    ]], {})
end

--- Clean summary of all registered globals.
---@return { renderers: string[], clicks: integer }
function Dispatch.stats()
    local renderer_names = {}
    for name in pairs(Dispatch._renderers) do
        renderer_names[#renderer_names + 1] = name
    end
    table.sort(renderer_names)
    return {
        renderers = renderer_names,
        clicks = vim.tbl_count(Dispatch._click_handlers),
    }
end

return Dispatch
