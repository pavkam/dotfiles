-- Notes extension: daily notes with project-local or global scope.
-- Replaces legacy notes.lua.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'

local Notes = Class('Notes', Extension)

function Notes:init()
    Extension.init(self, 'Notes')
end

function Notes:_root(global)
    if global then
        return vim.env.WORK_NOTES_ROOT or IDE.fs:data_dir()
    end
    local project = IDE:project()
    if not project then return IDE.fs:data_dir() end
    return IDE.fs:join(project:root(), '.nvim', 'notes')
end

function Notes:edit(global)
    local path = IDE.fs:join(self:_root(global), os.date('%Y-%m-%d') .. '.md')
    IDE.fs:mkdir(IDE.fs:dirname(path))
    IDE.buffers:open(path)
end

function Notes:grep(global)
    local root = self:_root(global)
    if not IDE.fs:is_directory(root) then
        IDE.ui:info('No notes saved')
        return
    end
    IDE.ui.finder:grep({ cwd = root })
end

function Notes:find(global)
    local root = self:_root(global)
    if not IDE.fs:is_directory(root) then
        IDE.ui:info('No notes saved')
        return
    end
    IDE.ui.finder:files({ cwd = root, hidden = true })
end

function Notes:on_register(ctx)
    local ext = self

    ctx:command('Note', function(args)
        local sub = args.fargs[1]

        -- :Note or :Note open → just open today's note
        if sub == 'open' or (not sub and args.range == 0) then
            ext:edit(args.bang)
            return
        end

        -- :Note with visual range → append selected lines to note
        local buf = Buffer.current()
        local lines = args.range > 0 and buf:lines(args.line1 - 1, args.line2) or nil
        if not lines or #lines == 0 then
            ext:edit(args.bang)
            return
        end

        local title
        if args.range == 2 then
            title = string.format('Lines %d-%d from %s:', args.line1, args.line2, buf:name() or '?')
        elseif args.range == 1 then
            title = string.format('Line %d from %s:', args.line1, buf:name() or '?')
        end

        local ft = buf:filetype()
        ext:edit(args.bang)

        local content = {}
        if title then content[#content + 1] = '### ' .. title end
        if #lines > 0 then
            content[#content + 1] = '```' .. ft
            for _, l in ipairs(lines) do content[#content + 1] = l end
            content[#content + 1] = '```'
        end
        IDE.ui:paste_lines(content)
    end, { desc = 'Open/Append to note', nargs = '?', bang = true })

    ctx:command('Notes', function(args)
        local sub = args.fargs[1]
        if sub == 'list' then
            ext:find(args.bang)
        else
            ext:grep(args.bang)
        end
    end, { desc = 'Search notes', nargs = '?', bang = true })
end

return Notes
