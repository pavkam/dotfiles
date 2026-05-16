-- File safety extension: view persistence, temp file handling, auto-mkdir, deleted file cleanup.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'

local FileSafety = Class('FileSafety', Extension)

function FileSafety:init()
    Extension.init(self, 'FileSafety')
    self._new_files = {}
end

function FileSafety:on_register(ctx)
    -- View save/restore (fold state, cursor position)
    local session_opts = IDE.config:option('sessionoptions') or ''
    local folds_in_session = session_opts:find('folds') ~= nil
    if not folds_in_session then
        ctx:hook({ 'BufWinLeave', 'BufWritePost', 'WinLeave' }, function(evt)
            if not Buffer.is_valid(evt.buf) then return end
            local buf = Buffer.get(evt.buf)
            if not buf:is_normal() then return end
            local option = IDE.config:use(evt.buf, 'view_activated', false)
            if option.get() then
                IDE.ui:save_view()
            end
        end, { desc = 'Save view on leave' })

        ctx:hook('BufWinEnter', function(evt)
            if not Buffer.is_valid(evt.buf) then return end
            local buf = Buffer.get(evt.buf)
            if not buf:is_normal() then return end
            local option = IDE.config:use(evt.buf, 'view_activated', false)
            if not option.get() then
                if not Buffer.is_transient(evt.buf) then
                    option.set(true)
                    IDE.ui:restore_view()
                end
            end
        end, { desc = 'Restore view on enter' })
    end

    -- Disable swap/undo for temp files
    ctx:hook('BufWritePre', function(evt)
        if Buffer.is_valid(evt.buf) then
            Buffer.get(evt.buf):set_option('undofile', false)
            if evt.file == 'COMMIT_EDITMSG' or evt.file == 'MERGE_MSG' then
                Buffer.get(evt.buf):set_option('swapfile', false)
            end
        end
    end, { pattern = { '/tmp/*', '*.tmp', '*.bak', 'COMMIT_EDITMSG', 'MERGE_MSG' }, desc = 'Disable undo for temp files' })

    ctx:hook({ 'BufNewFile', 'BufReadPre' }, function()
        local buf = Buffer.current()
        if buf:is_valid() then
            buf:set_option('undofile', false)
            buf:set_option('swapfile', false)
        end
        IDE.config:set_option('backup', false)
        IDE.config:set_option('writebackup', false)
    end, { pattern = { '/tmp/*', '$TMPDIR/*', '$TMP/*', '$TEMP/*', '*/shm/*', '/private/var/*' }, desc = 'Disable swap/backup for temp dirs' })

    -- Auto-create directories on save
    ctx:hook('BufWritePre', function(evt)
        if evt.match:match('^%w%w+://') then return end
        local file = vim.uv.fs_realpath(evt.match) or evt.match
        IDE.fs:mkdir(IDE.fs:dirname(file))
    end, { desc = 'Auto-create parent directories' })

    -- Track and clean up deleted files
    local new_files = self._new_files

    ctx:hook('BufNew', function(evt)
        if Buffer.is_special(evt.buf) then return end
        if not Buffer.is_valid(evt.buf) then return end
        local buf = Buffer.get(evt.buf)
        local path = buf:path()
        if path and not IDE.fs:is_file(path) then
            new_files[path] = true
        end
    end, { desc = 'Track new files' })

    ctx:hook({ 'BufDelete', 'BufEnter', 'FocusGained' }, function(evt)
        if Buffer.is_special(evt.buf) then return end
        if not Buffer.is_valid(evt.buf) then return end
        local buf = Buffer.get(evt.buf)
        local path = buf:path()
        if not path or IDE.fs:is_file(path) then return end

        if new_files[path] then
            if evt.event == 'BufDelete' then
                new_files[path] = nil
            end
            return
        end

        pcall(function() IDE.marks:forget(path) end)
        pcall(function() IDE.buffers:forget_oldfile(path) end)
        pcall(function() IDE.quickfix:forget(path) end)

        if evt.event ~= 'BufDelete' then
            buf:close(true)
        end
    end, { desc = 'Clean up deleted files' })

    -- Restore cursor position after opening a file
    ctx:hook({ 'BufReadPost', 'BufNew' }, function(evt)
        if Buffer.is_special(evt.buf) or Buffer.is_transient(evt.buf) then return end
        if not Buffer.is_valid(evt.buf) then return end
        local buf = Buffer.get(evt.buf)
        local cursor_mark = buf:mark('"')
        if cursor_mark[1] > 0 and cursor_mark[1] <= buf:line_count() then
            local Window = require 'ide.Window'
            local Position = require 'ide.Position'
            pcall(function() Window.current():set_cursor(Position(cursor_mark[1], math.max(1, cursor_mark[2] + 1))) end)
        end
    end, { desc = 'Restore cursor position' })

    -- File detection: trigger NormalFile/GitFile user events
    ctx:hook({ 'BufReadPost', 'BufNewFile', 'BufWritePost' }, function(evt)
        if not Buffer.is_valid(evt.buf) then return end
        local buf = Buffer.get(evt.buf)
        if not buf:is_normal() then return end
        local path = buf:path()
        if not path then return end

        if buf:var('ide_events_triggered') then return end
        buf:set_var('ide_events_triggered', true)
    end, { desc = 'Trigger NormalFile/GitFile events' })

    -- Binary file detection: make binary files read-only with a warning
    ctx:hook('BufReadPost', function(evt)
        if not Buffer.is_valid(evt.buf) then return end
        local buf = Buffer.get(evt.buf)
        if not buf:is_normal() then return end
        local path = buf:path()
        if not path then return end

        -- Check first 512 bytes for null bytes (binary indicator)
        local f = io.open(path, 'rb')
        if not f then return end
        local head = f:read(512)
        f:close()
        if head and head:find('\0') then
            buf:set_option('modifiable', false)
            buf:set_option('readonly', true)
            vim.schedule(function()
                IDE.ui:warn(string.format('Binary file detected: %s (read-only)', buf:name() or path))
            end)
        end
    end, { desc = 'Detect binary files' })
end

return FileSafety
