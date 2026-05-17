-- Desktop Extension: TurboVision-style desktop background.
-- Shows logo, recent files, and quick actions when no buffers are open.
-- Uses reactive function component for content rendering.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Timer = require 'ide.Timer'
local hooks = require 'ide.toolkit.hooks'
local C = require 'ide.toolkit.component'

local Desktop = Class('Desktop', Extension)

function Desktop:init()
    Extension.init(self, 'Desktop')
    self._buf = nil
    self._component = nil
    self._active = false
end

function Desktop:_define_highlights(ctx)
    local bg = '#222436'
    ctx:highlight('IDEDesktop', { fg = '#3b4261', bg = bg })
    ctx:highlight('IDEDesktopLogo', { fg = '#7dcfff', bg = bg, bold = true })
    ctx:highlight('IDEDesktopVersion', { fg = '#7aa2f7', bg = bg })
    ctx:highlight('IDEDesktopSection', { fg = '#e0af68', bg = bg })
    ctx:highlight('IDEDesktopFile', { fg = '#c0caf5', bg = bg })
    ctx:highlight('IDEDesktopKey', { fg = '#7dcfff', bg = bg })
    ctx:highlight('IDEDesktopHint', { fg = '#565f89', bg = bg, italic = true })
end

function Desktop:_is_desktop_needed()
    local bufs = IDE.buffers:listed()
    if #bufs == 0 then return true end
    if #bufs == 1 then
        local buf = bufs[1]
        if buf:is_valid() and (not buf:name() or buf:name() == '') then
            if buf:line_count() <= 1 then return true end
        end
    end
    return false
end

--- Gather recent file paths from oldfiles + listed buffers.
---@return string[]
local function gather_recent_files()
    local paths = {}
    local seen = {}
    for _, path in ipairs(vim.v.oldfiles or {}) do
        if #paths >= 6 then break end
        if not seen[path] and IDE.fs:is_file(path) then
            local rel = IDE.fs:display_path(path)
            if rel and #rel < 60 then
                seen[path] = true
                paths[#paths + 1] = path
            end
        end
    end
    if #paths == 0 then
        for buf_obj in IDE.buffers:iter() do
            if #paths >= 6 then break end
            local p = buf_obj:path()
            if p and not seen[p] and IDE.fs:is_file(p) then
                seen[p] = true
                paths[#paths + 1] = p
            end
        end
    end
    return paths
end

--- Function component for desktop content.
local function DesktopView(props)
    local recent = props.recent_files or {}
    local width = props.width or 80
    local height = props.height or 30

    local content_height = 20
    local mid = math.max(1, math.floor((height - content_height) / 2))

    local children = {}

    -- Blank lines before logo
    for i = 1, mid - 1 do
        children[#children + 1] = { type = 'text', text = '' }
    end

    -- Logo
    local logo = {
        '╔╦╗╦ ╦╦═╗╔╗ ╔═╗╦  ╦╦╔╦╗',
        ' ║ ║ ║╠╦╝╠╩╗║ ║╚╗╔╝║║║║',
        ' ╩ ╚═╝╩╚═╚═╝╚═╝ ╚╝ ╩╩ ╩',
    }
    for _, line in ipairs(logo) do
        local pad = math.max(0, math.floor((width - IDE.text:display_width(line)) / 2))
        children[#children + 1] = { type = 'text', text = string.rep(' ', pad) .. line, hl = 'IDEDesktopLogo' }
    end

    -- Version
    children[#children + 1] = { type = 'text', text = '' }
    local ver = 'Neovim ' .. vim.version().major .. '.' .. vim.version().minor .. '.' .. vim.version().patch
    local vpad = math.max(0, math.floor((width - #ver) / 2))
    children[#children + 1] = { type = 'text', text = string.rep(' ', vpad) .. ver, hl = 'IDEDesktopVersion' }

    -- Recent files
    children[#children + 1] = { type = 'text', text = '' }
    children[#children + 1] = { type = 'text', text = '' }
    local sec = '─── Recent Files ───'
    local spad = math.max(0, math.floor((width - IDE.text:display_width(sec)) / 2))
    children[#children + 1] = { type = 'text', text = string.rep(' ', spad) .. sec, hl = 'IDEDesktopSection' }

    if #recent > 0 then
        for i, path in ipairs(recent) do
            local rel = IDE.fs:display_path(path)
            local icon = ''
            if IDE.icons and IDE.icons:is_loaded() then
                local ic = IDE.icons:for_file(IDE.fs:basename(path), IDE.fs:extension(path))
                if ic then icon = ic:char() .. ' ' end
            end
            local entry = string.format(' %d  %s%s', i, icon, rel or path)
            local epad = math.max(0, math.floor((width - IDE.text:display_width(entry)) / 2))
            children[#children + 1] = { type = 'text', text = string.rep(' ', epad) .. entry, hl = 'IDEDesktopFile' }
        end
    else
        local hint = 'Press Ctrl+P to open a file'
        local hpad = math.max(0, math.floor((width - #hint) / 2))
        children[#children + 1] = { type = 'text', text = string.rep(' ', hpad) .. hint, hl = 'IDEDesktopHint' }
    end

    -- Quick actions
    children[#children + 1] = { type = 'text', text = '' }
    local asec = '─── Quick Actions ───'
    local apad = math.max(0, math.floor((width - IDE.text:display_width(asec)) / 2))
    children[#children + 1] = { type = 'text', text = string.rep(' ', apad) .. asec, hl = 'IDEDesktopSection' }

    local actions = {
        { 'Ctrl+P', 'Open file',        '' },
        { 'Ctrl+E', 'File explorer',    '󰙅' },
        { 'Ctrl+F', 'Search in files',  '' },
        { 'F10',    'Menu bar',         '' },
    }
    for _, a in ipairs(actions) do
        local line = string.format('%s  %-10s  %s', a[3], a[1], a[2])
        local lpad = math.max(0, math.floor((width - IDE.text:display_width(line)) / 2))
        children[#children + 1] = { type = 'text', text = string.rep(' ', lpad) .. line, hl = 'IDEDesktopKey' }
    end

    return children
end

function Desktop:_show_desktop()
    if self._active then return end

    local buf = Buffer.create({ listed = false, scratch = true })
    buf:set_option('bufhidden', 'hide')
    buf:set_option('filetype', 'ide-desktop')
    buf:set_option('buftype', 'nofile')

    local recent = gather_recent_files()

    -- Show in FramedWindow if available, otherwise use current window
    local target_win = nil
    if IDE._window_chrome and IDE._window_chrome._frame and IDE._window_chrome._frame:is_valid() then
        local frame = IDE._window_chrome._frame
        frame:set_buffer(buf:id())
        local win_id = frame:window_id()
        target_win = Window.get(win_id)
    else
        target_win = Window.current()
        if target_win then target_win:set_buffer(buf) end
    end

    if target_win and target_win:is_valid() then
        target_win:set_option('number', false)
        target_win:set_option('relativenumber', false)
        target_win:set_option('signcolumn', 'no')
        target_win:set_option('statuscolumn', '')
        target_win:set_option('cursorline', false)
        target_win:set_option('winhl', 'Normal:IDEDesktop,EndOfBuffer:IDEDesktop')
    end

    -- Use actual window dimensions for centering (not content_area which is larger)
    local win_w = target_win and target_win:is_valid() and target_win:width() or 80
    local win_h = target_win and target_win:is_valid() and target_win:height() or 40

    -- Mount component with the target window so Canvas uses correct dimensions
    self._component = C.mount(DesktopView, {
        recent_files = recent,
        width = win_w,
        height = win_h,
    }, buf, target_win)

    self._buf = buf
    self._recent_paths = recent
    self._active = true

    -- Bind number keys to open recent files
    for i = 1, math.min(#recent, 6) do
        local path = recent[i]
        buf:bind_key('n', tostring(i), function()
            Buffer.open(path)
        end)
    end
end

function Desktop:_hide_desktop()
    if not self._active then return end
    if self._component then C.unmount(self._component); self._component = nil end
    if self._buf and self._buf:is_valid() then
        pcall(function() self._buf:close(true) end)
    end
    self._buf = nil
    self._active = false
    -- Restore frame window settings that desktop overrode
    if IDE._window_chrome and IDE._window_chrome._frame and IDE._window_chrome._frame:is_valid() then
        local win_id = IDE._window_chrome._frame:window_id()
        local win = Window.get(win_id)
        if win and win:is_valid() then
            win:set_option('number', true)
            win:set_option('relativenumber', true)
            win:set_option('signcolumn', 'yes:1')
            win:set_option('cursorline', true)
        end
    end
end

function Desktop:on_register(ctx)
    self:_define_highlights(ctx)

    local desktop = self
    local check = Timer.debounce(100, function()
        if desktop:_is_desktop_needed() then
            desktop:_show_desktop()
        elseif desktop._active then
            desktop:_hide_desktop()
        end
    end)

    -- Check after other extensions finish loading
    vim.defer_fn(function() check() end, 500)
    -- Re-check after the frame is created (handles race with window_chrome)
    vim.defer_fn(function() check() end, 1500)

    ctx:hook({ 'BufAdd', 'BufDelete', 'BufWipeout', 'VimEnter' }, function()
        check()
    end, { desc = 'Desktop: check if desktop needed' })
end

function Desktop:on_unregister()
    self:_hide_desktop()
end

function Desktop:show_desktop()
    self:_show_desktop()
end

function Desktop:__tostring()
    return string.format('Desktop(%s)', self._active and 'visible' or 'hidden')
end

return Desktop
