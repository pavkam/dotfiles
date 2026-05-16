-- Desktop Extension: TurboVision-style desktop background.
-- Shows a ░ pattern fill when no normal buffers are open,
-- like the classic Turbo Pascal / Borland C++ desktop.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Timer = require 'ide.Timer'

local Desktop = Class('Desktop', Extension)

function Desktop:init()
    Extension.init(self, 'Desktop')
    self._buf = nil
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
    -- Also show desktop if the only buffer is unnamed and empty
    if #bufs == 1 then
        local buf = bufs[1]
        if buf:is_valid() and (not buf:name() or buf:name() == '') then
            local lines = buf:line_count()
            if lines <= 1 then return true end
        end
    end
    return false
end

function Desktop:_show_desktop()
    if self._active then return end

    local buf = Buffer.create({ listed = false, scratch = true })
    buf:set_option('bufhidden', 'hide')
    buf:set_option('filetype', 'ide-desktop')
    buf:set_option('buftype', 'nofile')

    local Canvas = require 'ide.toolkit.Canvas'
    local area = Window.content_area and Window.content_area() or { width = 80, height = 40 }
    local width = area.width
    local height = area.height

    local c = Canvas(width, height)
    -- Center content vertically: logo(3) + version(1) + gap(2) + section(1) + files(2) + gap(1) + section(1) + actions(4) = ~15 lines
    local content_height = 20
    local mid = math.max(3, math.floor((height - content_height) / 2))

    -- ASCII art logo — bright cyan/blue for impact
    local logo = {
        '╔╦╗╦ ╦╦═╗╔╗ ╔═╗╦  ╦╦╔╦╗',
        ' ║ ║ ║╠╦╝╠╩╗║ ║╚╗╔╝║║║║',
        ' ╩ ╚═╝╩╚═╚═╝╚═╝ ╚╝ ╩╩ ╩',
    }
    for i, line in ipairs(logo) do
        c:center(mid + i - 1, line, 'IDEDesktopLogo')
    end
    c:center(mid + 4, 'Neovim ' .. vim.version().major .. '.' .. vim.version().minor .. '.' .. vim.version().patch, 'IDEDesktopVersion')

    -- Gather recent files from oldfiles + recent buffers
    local recent_paths = {}
    local seen = {}

    -- Try oldfiles first (shada)
    for _, path in ipairs(vim.v.oldfiles or {}) do
        if #recent_paths >= 8 then break end
        if not seen[path] and IDE.fs:is_file(path) then
            local rel = IDE.fs:display_path(path)
            if #rel < 60 then
                seen[path] = true
                recent_paths[#recent_paths + 1] = path
            end
        end
    end

    -- Fall back to listed buffers if oldfiles is empty
    if #recent_paths == 0 then
        for buf_obj in IDE.buffers:iter() do
            if #recent_paths >= 8 then break end
            local p = buf_obj:path()
            if p and not seen[p] and IDE.fs:is_file(p) then
                seen[p] = true
                recent_paths[#recent_paths + 1] = p
            end
        end
    end

    self._recent_paths = recent_paths

    -- Recent files section
    local row = mid + 7
    c:center(row, '─── Recent Files ───', 'IDEDesktopSection')
    row = row + 1
    if #recent_paths > 0 then
        for i, path in ipairs(recent_paths) do
            row = row + 1
            local rel = IDE.fs:display_path(path)
            local icon = ''
            if IDE.icons and IDE.icons:is_loaded() then
                local ic = IDE.icons:for_file(IDE.fs:basename(path), IDE.fs:extension(path))
                if ic then icon = ic:char() .. ' ' end
            end
            c:center(row, string.format(' %d  %s%s', i, icon, rel), 'IDEDesktopFile')
        end
    else
        row = row + 1
        c:center(row, 'Press Ctrl+P to open a file', 'IDEDesktopHint')
    end

    -- Quick actions section
    row = row + 2
    c:center(row, '─── Quick Actions ───', 'IDEDesktopSection')
    local actions = {
        { 'Ctrl+P', 'Open file',        '' },
        { 'Ctrl+E', 'File explorer',    '󰙅' },
        { 'Ctrl+F', 'Search in files',  '' },
        { 'F10',    'Menu bar',         '' },
    }
    for _, a in ipairs(actions) do
        row = row + 1
        c:center(row, string.format('%s  %-10s  %s', a[3], a[1], a[2]), 'IDEDesktopKey')
    end

    c:render(buf)

    -- Show in FramedWindow if available, otherwise in current window
    if IDE._window_chrome and IDE._window_chrome._frame and IDE._window_chrome._frame:is_valid() then
        IDE._window_chrome._frame:set_buffer(buf:id())
    else
        local win = Window.current()
        win:set_buffer(buf)
        win:set_option('cursorline', false)
        win:set_option('number', false)
        win:set_option('relativenumber', false)
        win:set_option('signcolumn', 'no')
        win:set_option('statuscolumn', '')
        win:set_option('winhl', 'Normal:IDEDesktop')
    end

    self._buf = buf
    self._active = true

    -- Bind number keys to open recent files
    for i = 1, math.min(#self._recent_paths, 6) do
        local path = self._recent_paths[i]
        buf:bind_key('n', tostring(i), function()
            Buffer.open(path)
        end)
    end
end

function Desktop:_hide_desktop()
    if not self._active then return end
    if self._buf and self._buf:is_valid() then
        pcall(function() self._buf:close(true) end)
    end
    self._buf = nil
    self._active = false
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

    -- Delayed startup check — wait for FramedWindow to be ready
    vim.defer_fn(function() check() end, 500)

    ctx:hook({ 'BufAdd', 'BufDelete', 'BufWipeout', 'VimEnter' }, function()
        check()
    end, { desc = 'Desktop: check if desktop needed' })
end

function Desktop:on_unregister()
    self:_hide_desktop()
end

function Desktop:__tostring()
    return string.format('Desktop(%s)', self._active and 'visible' or 'hidden')
end

return Desktop
