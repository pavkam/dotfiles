-- File operations extension: rename and delete files using IDE abstractions.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'

local FileOperations = Class('FileOperations', Extension)

function FileOperations:init()
    Extension.init(self, 'FileOperations')
end

function FileOperations:rename(new_name)
    local buf = Buffer.current()
    local old_path = buf:path()
    if not old_path then return end

    local directory = IDE.fs:dirname(old_path)
    local new_path = IDE.fs:join(directory, new_name)

    if not IDE.fs:is_file(old_path) then
        buf:set_name(new_name)
        return
    end

    local ok, err = IDE.fs:rename(old_path, new_path)
    if not ok then
        IDE.ui:error(string.format('Failed to rename file: %s', err))
        return
    end

    buf:close(true)
    IDE.buffers:open(new_path)

    IDE.lsp:notify_file_renamed(old_path, new_path) -- global operation: notifies ALL LSP servers
end

function FileOperations:delete(force)
    local buf = Buffer.current()
    local path = buf:path()

    if not path or not IDE.fs:is_file(path) then
        buf:close(true)
        return
    end

    if not force then
        IDE.ui:confirm(string.format('Delete %s?', IDE.fs:basename(path)), function(yes)
            if yes then
                self:_do_delete(buf, path)
            end
        end)
        return
    end

    self:_do_delete(buf, path)
end

function FileOperations:_do_delete(buf, path)
    local ok, err = IDE.fs:delete(path)
    if not ok then
        IDE.ui:error(string.format('Failed to delete file: %s', err))
        return
    end
    buf:close(true)
end

function FileOperations:on_register(ctx)
    local ext = self

    ctx:command('Rename', function(args)
        if args.args ~= '' then
            ext:rename(args.args)
            return
        end

        local buf = Buffer.current()
        local old_name = buf:name() or ''
        IDE.ui:input('New name: ', function(new_name)
            if new_name and new_name ~= '' and new_name ~= old_name then
                ext:rename(new_name)
            end
        end, { default = old_name })
    end, { desc = 'Rename current file', nargs = '?' })

    ctx:command('Delete', function(args)
        ext:delete(args.bang)
    end, { desc = 'Delete current file', bang = true })

    if IDE.shell:has('jq') then
        ctx:hook('FileType', function(evt)
            ctx:keymap('n', '=', '<cmd>%!jq .<cr>', { buffer = evt.buf, desc = 'Pretty-format JSON' })
        end, { pattern = { 'json', 'jsonc' }, desc = 'jq format for JSON' })
    end

    ctx:notify('File operations active')
end

return FileOperations
