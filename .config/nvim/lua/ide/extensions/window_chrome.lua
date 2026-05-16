-- WindowChrome Extension: TurboVision MDI window manager.
-- Wraps editor buffers in FramedWindow instances — floating windows
-- with double-line borders on all 4 sides, title bar, and footer.
-- Replaces the winbar/statuscolumn/statusline border hacks with
-- proper bordered floating windows.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local FramedWindow = require 'ide.FramedWindow'
local Splitter = require 'ide.toolkit.Splitter'
local Timer = require 'ide.Timer'

local WindowChrome = Class('WindowChrome', Extension)

function WindowChrome:init()
    Extension.init(self, 'WindowChrome')
    self._frame = nil ---@type FramedWindow|nil
    self._splitter = nil ---@type Splitter|nil
    self._host_win = nil ---@type Window|nil
    self._blank_buf = nil ---@type Buffer|nil
end

-- ── Highlights ──────────────────────────────────────────────────

function WindowChrome:_define_highlights(ctx)
    -- Host window (behind the float) — bg MUST match Normal bg exactly
    -- so any float transparency is invisible
    local normal_bg = IDE.theme:bg('Normal') or '#222436'
    ctx:highlight('IDEHostBg', { fg = normal_bg, bg = normal_bg })
    -- Frame gutter must have explicit bg matching Normal to prevent bleed-through
    local editor_bg = IDE.theme:bg('Normal') or '#222436'
    ctx:highlight('IDEFrameGutter', { fg = '#3b4261', bg = editor_bg })
    ctx:highlight('IDEFrameLineNr', { fg = '#3b4261', bg = editor_bg })
    ctx:highlight('IDEFrameCurLineNr', { fg = '#e0af68', bg = editor_bg, bold = true })

    ctx:highlight('IDEWinBorder', { fg = '#3b4261' })
    ctx:highlight('IDEWinBorderNC', { fg = '#292e42' })
    ctx:highlight('IDEWinTitle', { fg = '#c0caf5', bold = true })
    ctx:highlight('IDEWinTitleNC', { fg = '#565f89' })
    ctx:highlight('IDEWinButton', { fg = '#7aa2f7' })
    ctx:highlight('IDEWinButtonNC', { fg = '#3b4261' })
    ctx:highlight('IDEWinNumber', { fg = '#7aa2f7', bold = true })
    ctx:highlight('IDEWinNumberNC', { fg = '#3b4261' })
    ctx:highlight('IDEWinPos', { fg = '#7aa2f7' })
    ctx:highlight('IDEWinPosNC', { fg = '#3b4261' })
    ctx:highlight('IDEScrollTrack', { fg = '#3b4261' })
    ctx:highlight('IDEScrollThumb', { fg = '#7aa2f7' })
    ctx:highlight('IDEScrollButton', { fg = '#565f89' })

    -- Dialog defaults (overridden by TurboVision theme)
    ctx:highlight('IDEDialogNormal', { bg = '#1e2030', fg = '#c0caf5' })
    ctx:highlight('IDEDialogBorder', { bg = '#1e2030', fg = '#3b4261' })
    ctx:highlight('IDEDialogTitle', { bg = '#1e2030', fg = '#c0caf5', bold = true })
    ctx:highlight('IDEDialogShadow', { bg = '#000000' })
    ctx:highlight('IDEDialogHotkey', { fg = '#e0af68', bold = true })
    ctx:highlight('IDEDialogFocused', { bg = '#3b4261', fg = '#c0caf5', bold = true })
    ctx:highlight('IDEDialogCheckbox', { fg = '#c0caf5' })
    ctx:highlight('IDEDialogCheckMark', { fg = '#9ece6a', bold = true })
    ctx:highlight('IDEDialogRadio', { fg = '#c0caf5' })
    ctx:highlight('IDEDialogButton', { bg = '#3b4261', fg = '#c0caf5' })
    ctx:highlight('IDEDialogButtonPrimary', { bg = '#7aa2f7', fg = '#1a1b26', bold = true })
    ctx:highlight('IDEDialogButtonFocused', { bg = '#7aa2f7', fg = '#1a1b26', bold = true })
    ctx:highlight('IDEDialogListSelected', { bg = '#3b4261', fg = '#c0caf5', bold = true })
    ctx:highlight('IDEDialogListDisabled', { fg = '#3b4261', italic = true })
end

-- ── Frame management ────────────────────────────────────────────

function WindowChrome:_ensure_frame()
    -- Ensure blank buffer options are always correct
    if self._blank_buf and self._blank_buf:is_valid() then
        if self._blank_buf:option('buftype') ~= 'nofile' then
            self._blank_buf:set_option('buftype', 'nofile')
            self._blank_buf:set_option('buflisted', false)
            self._blank_buf:set_option('bufhidden', 'hide')
        end
    end

    local cur_win = Window.current()
    if not cur_win then return end
    local cur_win_id = cur_win:id()
    local buf = Buffer.current()
    if not buf then return end
    local cur_buf_id = buf:id()

    -- Recover from empty [No Name] buffer after :bd
    if buf:is_valid() and (buf:name() or '') == '' and buf:option('buftype') == '' then
        for listed_buf in IDE.buffers:iter() do
            if listed_buf:is_valid() and listed_buf:is_listed()
                and listed_buf:id() ~= cur_buf_id and (listed_buf:name() or '') ~= '' then
                cur_win:set_buffer(listed_buf)
                return
            end
        end
        -- No listed buffers remain — show desktop
        local desktop = IDE and IDE:extension('Desktop')
        if desktop and desktop.show_desktop then
            vim.schedule(function() desktop:show_desktop() end)
        end
    end

    -- Don't frame special buffers
    if not buf:is_normal() then return end
    if buf:filetype() == 'lazy' then return end

    -- If we're in the host window (a :e or :bp landed there), redirect to the active frame
    -- Skip terminal buffers and other IDE-managed buffers
    local host_win_id = self._host_win and self._host_win:id() or nil
    local skip = buf:is_valid()
        and (buf:filetype() == 'ide-terminal' or vim.b[cur_buf_id].ide_terminal)
    if self._frame and self._frame:is_valid() and cur_win_id == host_win_id and not skip then
        local target_frame = (self._splitter and self._splitter:active_frame()) or self._frame
        target_frame:set_buffer(cur_buf_id)
        local target_win = Window.get(target_frame:window_id())
        if target_win then target_win:focus() end
        -- Reset host to blank
        if self._blank_buf and self._blank_buf:is_valid() and self._host_win then
            self._host_win:set_buffer(self._blank_buf)
        end
        return
    end

    -- Check if current window is a managed frame
    if self._frame and self._frame:is_valid() and cur_win_id ~= self._frame:window_id() then
        local managed_frame = nil
        if self._splitter then
            for i = 1, self._splitter:count() do
                local sf = self._splitter._frames[i]
                if sf and sf:is_valid() and sf:window_id() == cur_win_id then
                    managed_frame = sf
                    break
                end
            end
        end

        if managed_frame then
            managed_frame:refresh()
            return
        end

        -- Stray normal window — close it and redirect
        if not vim.w[cur_win_id].ide_terminal then
            local cfg = cur_win:config()
            if not cfg.relative or cfg.relative == '' then
                if #Window.list() <= 2 then return end
                local target = (self._splitter and self._splitter:active_frame()) or self._frame
                if not target or not target:is_valid() then return end
                target:set_buffer(cur_buf_id)
                local tw = Window.get(target:window_id())
                if tw then tw:focus() end
                pcall(function() cur_win:close(true) end)
                return
            end
        end
    end

    -- Current window IS the primary frame — refresh or switch buffer
    if self._frame and self._frame:is_valid() and cur_win_id == self._frame:window_id() then
        self._frame:refresh()
        return
    end

    -- Frame exists but we're somewhere else — route to frame
    if self._frame and self._frame:is_valid() then
        self._frame:refresh()
        return
    end

    -- Remember the host window and replace its buffer with an empty one
    self._host_win = Window.current()
    if not self._blank_buf or not self._blank_buf:is_valid() then
        self._blank_buf = Buffer.create({ listed = false, scratch = true })
    end
    self._blank_buf:set_option('bufhidden', 'hide')
    self._blank_buf:set_option('buftype', 'nofile')
    self._blank_buf:set_option('modifiable', false)
    self._host_win:set_buffer(self._blank_buf)
    self._host_win:set_option('number', false)
    self._host_win:set_option('relativenumber', false)
    self._host_win:set_option('signcolumn', 'no')
    self._host_win:set_option('statuscolumn', '')
    self._host_win:set_option('foldcolumn', '0')
    self._host_win:set_option('cursorline', false)
    self._host_win:set_option('winblend', 0)
    self._host_win:set_option('winhighlight', 'Normal:IDEHostBg,EndOfBuffer:IDEHostBg,SignColumn:IDEHostBg,FoldColumn:IDEHostBg')

    -- Clean up any orphaned scrollbar floats before creating new frame
    for _, w in ipairs(Window.list()) do
        local cfg = w:config()
        if cfg.zindex == 51 and cfg.width == 1 then
            pcall(function() w:close(true) end)
        end
    end

    -- Create the frame
    self._frame = FramedWindow({
        buf = cur_buf_id,
        number = 1,
    })
    self._frame:fill()
    self._frame:show()
end

function WindowChrome:close_current()
    -- In split mode, close the active frame and unsplit if only one remains
    if self._splitter and self._splitter:count() > 1 then
        local active_idx = self._splitter._active
        self._splitter:close_frame(active_idx)

        if self._splitter:count() == 1 then
            -- Unsplit: promote remaining frame to full size
            local remaining = self._splitter._frames[1]
            self._splitter = nil
            self._frame = remaining
            self._frame:set_number(1)
            self._frame:fill()
        else
            -- Re-layout remaining frames
            local row = 1
            local width = vim.o.columns - 2
            local height = vim.o.lines - 5
            self._splitter:layout(row, 0, width, height)
            local active = self._splitter:active_frame()
            if active and active:is_valid() then
                local aw = Window.get(active:window_id())
                if aw then aw:focus() end
            end
        end
        return
    end

    -- Single frame mode
    if not self._frame or not self._frame:is_valid() then return end
    local buf_id = self._frame:buffer_id()

    local close_buf = Buffer.get(buf_id)
    if close_buf and close_buf:is_modified() then
        self._frame:close()
        self._frame = nil
        vim.schedule(function()
            vim.cmd('confirm bdelete ' .. buf_id)
            self:_ensure_frame()
        end)
        return
    end

    self._frame:close()
    self._frame = nil
    vim.schedule(function()
        pcall(vim.cmd, 'bdelete ' .. buf_id)
        self:_ensure_frame()
    end)
end

function WindowChrome:toggle_maximize_current()
    if self._splitter and self._splitter:count() > 1 then
        -- Close other frames, keep current
        local active = self._splitter:active_frame()
        if active then
            local buf_id = active:buffer_id()
            self._splitter:close_all()
            self._splitter = nil
            self._frame = FramedWindow({ buf = buf_id, number = 1 })
            self._frame:fill()
            self._frame:show()
        end
    elseif self._frame and self._frame:is_valid() then
        self._frame:fill()
    end
end

--- Internal: perform a split in the given direction.
---@param direction 'vertical'|'horizontal'
function WindowChrome:_split(direction)
    if not self._frame or not self._frame:is_valid() then return end

    -- Block splits on non-normal buffers (desktop, panels)
    local Buffer = require 'ide.Buffer'
    local cur_buf = self._frame:buffer_id()
    if not Buffer.is_valid(cur_buf) or not Buffer.get(cur_buf):is_normal() then
        IDE.ui:info('Open a file first')
        return
    end

    if not self._splitter then
        self._splitter = Splitter({ direction = direction })
        self._splitter:add(self._frame)
    end

    local frame2 = FramedWindow({ buf = cur_buf, number = self._splitter:count() + 1 })
    self._splitter:add(frame2)

    -- Layout all frames within the editor area
    local area = Window.content_area()
    self._splitter:layout(area.row, area.col, area.width, area.height)

    frame2:show()
    self._splitter:cycle(1)
end

--- Split the current window vertically.
function WindowChrome:split_vertical()
    self:_split('vertical')
end

--- Split the current window horizontally.
function WindowChrome:split_horizontal()
    self:_split('horizontal')
end

-- ── Registration ────────────────────────────────────────────────

function WindowChrome:on_register(ctx)
    self:_define_highlights(ctx)
    IDE._window_chrome = self

    -- Clean up orphaned FramedWindow floats from previous sessions (z50-51 only, skip toasts/panels)
    local cur_win_id = Window.current():id()
    for _, w in ipairs(Window.list()) do
        local cfg = w:config()
        if cfg.zindex and cfg.zindex >= 50 and cfg.zindex <= 52 and cfg.relative and cfg.relative ~= '' then
            if cfg.width == 1 or (cfg.zindex == 50 and w:id() ~= cur_win_id) then
                pcall(function() w:close(true) end)
            end
        end
    end

    -- Hide winbar — FramedWindow title replaces it
    IDE.config:set_option('winbar', '')
    -- Global statusline at very bottom = TV status bar (mode + F-keys)
    IDE.config:set_option('laststatus', 3)
    vim.opt.fillchars:append({ eob = ' ' })

    -- Global status bar: mode + F-keys + info
    local Dispatch = require 'ide.Dispatch'
    Dispatch.renderer('global_stl', function()
        return IDE.statusbar and IDE.statusbar:render() or ''
    end)
    vim.o.statusline = '%!v:lua.IDE_render_global_stl()'

    -- Create the frame after a short delay (let other extensions finish)
    local chrome = self
    vim.schedule(function()
        vim.schedule(function()
            chrome:_ensure_frame()
        end)
    end)

    -- Re-frame on buffer switch
    local refresh = Timer.debounce(30, function()
        chrome:_ensure_frame()
    end)

    ctx:hook({ 'BufEnter', 'BufWinEnter' }, function()
        refresh()
    end, { desc = 'WindowChrome: frame buffer' })

    ctx:hook('BufDelete', function(ev)
        vim.schedule(function()
            if not chrome._frame or not chrome._frame:is_valid() then return end
            local frame_buf = chrome._frame:buffer_id()
            if frame_buf == ev.buf or not Buffer.is_valid(frame_buf) then
                -- Find a listed buffer to switch to
                local next_buf = nil
                for b in IDE.buffers:iter() do
                    if b:is_valid() and b:is_listed() and b:id() ~= ev.buf then
                        next_buf = b
                        break
                    end
                end
                -- Fallback: any normal buffer
                if not next_buf then
                    for b in IDE.buffers:iter() do
                        if b:is_valid() and b:id() ~= ev.buf and b:option('buftype') == '' then
                            next_buf = b
                            break
                        end
                    end
                end
                if next_buf then
                    chrome._frame:set_buffer(next_buf)
                else
                    local scratch = Buffer.create({ listed = true, scratch = true })
                    chrome._frame:set_buffer(scratch)
                end
            end
        end)
    end, { desc = 'WindowChrome: recover from buffer deletion' })

    -- Refresh title on buffer changes (name, modified state)
    local update_title = Timer.debounce(100, function()
        if chrome._frame and chrome._frame:is_valid() then
            chrome._frame:refresh()
        end
    end)

    ctx:hook({ 'BufModifiedSet', 'TextChanged' }, function()
        update_title()
    end, { desc = 'WindowChrome: refresh title on modify' })

    -- Refresh scrollbar on scroll/cursor (lower frequency)
    local update_scrollbar = Timer.debounce(80, function()
        if chrome._frame and chrome._frame:is_valid() then
            chrome._frame:refresh()
        end
    end)

    ctx:hook({ 'CursorMoved', 'CursorMovedI', 'WinScrolled' }, function()
        update_scrollbar()
    end, { desc = 'WindowChrome: refresh scrollbar on cursor' })

    -- Resize frame when terminal resizes
    ctx:hook('VimResized', function()
        -- Re-ensure tabline and statusline are visible after resize
        IDE.config:set_option('showtabline', 2)
        IDE.config:set_option('laststatus', 3)
        vim.schedule(function()
            if chrome._splitter and chrome._splitter:count() > 1 then
                chrome._splitter:layout(1, 0, vim.o.columns - 2, vim.o.lines - 5)
            elseif chrome._frame and chrome._frame:is_valid() then
                chrome._frame:fill()
            end
        end)
    end, { desc = 'WindowChrome: resize on terminal resize' })

    -- F6 cycles between FramedWindows
    ctx:keymap('n', '<F6>', function()
        if chrome._splitter and chrome._splitter:count() > 1 then
            chrome._splitter:cycle(1)
        else
            Window.cycle()
        end
    end, { desc = 'Next window' })

    ctx:keymap('n', '<S-F6>', function()
        if chrome._splitter and chrome._splitter:count() > 1 then
            chrome._splitter:cycle(-1)
        else
            Window.cycle_reverse()
        end
    end, { desc = 'Previous window' })

    -- Split commands
    ctx:command('IDESplitVertical', function()
        chrome:split_vertical()
    end, { desc = 'Split window vertically' })

    ctx:command('IDESplitHorizontal', function()
        chrome:split_horizontal()
    end, { desc = 'Split window horizontally' })

    ctx:command('IDESplitClose', function()
        chrome:close_current()
    end, { desc = 'Close current pane (unsplit if split)' })

    -- Resize split with Ctrl+Shift+Arrow keys
    ctx:keymap('n', '<C-S-Left>', function()
        if chrome._splitter then
            chrome._splitter:resize(-0.05)
            chrome._splitter:layout(1, 0, vim.o.columns - 2, vim.o.lines - 5)
        end
    end, { desc = 'Shrink split' })

    ctx:keymap('n', '<C-S-Right>', function()
        if chrome._splitter then
            chrome._splitter:resize(0.05)
            chrome._splitter:layout(1, 0, vim.o.columns - 2, vim.o.lines - 5)
        end
    end, { desc = 'Grow split' })
end

function WindowChrome:on_unregister()
    if self._frame then
        self._frame:close()
        self._frame = nil
    end
    IDE._window_chrome = nil
end

function WindowChrome:__tostring()
    return string.format('WindowChrome(frame=%s)', self._frame or 'none')
end

return WindowChrome
