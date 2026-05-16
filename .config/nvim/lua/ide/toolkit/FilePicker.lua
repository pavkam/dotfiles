-- FilePicker: TurboVision-style file picker dialog.
-- Extends SearchableList with async file scanning and fuzzy filtering.

local SearchableList = require 'ide.toolkit.SearchableList'
local Buffer = require 'ide.Buffer'

local FilePicker = Class('FilePicker', SearchableList)

---@param opts { title?: string, cwd?: string, on_select?: fun(path: string), hidden?: boolean }
function FilePicker:init(opts)
    opts = opts or {}
    SearchableList.init(self, {
        title = opts.title or '  Open File',
        width = 0.5,
        height = 0.6,
        preview = true,
    })
    self._cwd = opts.cwd or (IDE and IDE.git:root()) or (IDE and IDE.fs:cwd()) or vim.fn.getcwd()
    self._ext_on_select = opts.on_select
    self._hidden = opts.hidden or false
    self._files = {}
    self._filtered = {}
    self._search_handle = nil
end

function FilePicker:items()
    return self._filtered
end

function FilePicker:total_count()
    return #self._files
end

function FilePicker:show()
    SearchableList.show(self)
    self:_scan_files()
end

function FilePicker:_scan_files()
    local cmd = { 'find', self._cwd, '-type', 'f', '-maxdepth', '8',
        '-not', '-path', '*/.git/*',
        '-not', '-path', '*/node_modules/*',
        '-not', '-path', '*/__pycache__/*',
        '-not', '-path', '*/.cache/*',
    }

    local fd_bin = IDE.fs:executable('fd') and 'fd'
        or (IDE.fs:executable('fdfind') and 'fdfind' or nil)
    if fd_bin then
        cmd = { fd_bin, '--type', 'f', '--max-depth', '8',
            '--hidden', '--exclude', '.git',
            '--exclude', 'node_modules',
            '--exclude', '__pycache__',
            '--exclude', '.cache',
            '.', self._cwd,
        }
    end

    local prefix = self._cwd .. '/'
    local fp = self

    self._search_handle = IDE.shell:run(cmd[1], vim.list_slice(cmd, 2), { cwd = self._cwd }, function(result)
        local files = {}
        for path in (result.stdout or ''):gmatch('[^\n]+') do
            local rel = path
            if path:sub(1, #prefix) == prefix then rel = path:sub(#prefix + 1) end
            if rel ~= '' then files[#files + 1] = rel end
        end
        table.sort(files)
        fp._files = files
        fp._filtered = files
        if fp._mounted then fp:_render() end
    end)
end

function FilePicker:on_query_change(query)
    if query == '' then
        self._filtered = self._files
    else
        local q = query:lower()
        self._filtered = {}
        for _, f in ipairs(self._files) do
            if f:lower():find(q, 1, true) then
                self._filtered[#self._filtered + 1] = f
            end
        end
    end
    self._selected = math.min(1, #self._filtered)
    self._scroll = 0
end

function FilePicker:preview_path(item)
    return { path = self._cwd .. '/' .. item }
end

function FilePicker:render_item(canvas, row, item, width)
    local icon = '  '
    if IDE and IDE.icons and IDE.icons:is_loaded() then
        local fname = IDE.fs:basename(item)
        local ext = IDE.fs:extension(item)
        local ic = IDE.icons:for_file(fname, ext)
        if ic then icon = ic:char() .. ' ' end
    end
    canvas:text(row, 5, icon .. item)
end

function FilePicker:on_submit(item)
    local path = self._cwd .. '/' .. item
    local cb = self._ext_on_select
    -- Don't double-close (SearchableList:_submit already calls close)
    vim.schedule(function()
        if cb then
            cb(path)
        else
            Buffer.open(path)
        end
    end)
end

function FilePicker:close()
    if self._search_handle then
        pcall(self._search_handle.kill, self._search_handle)
        self._search_handle = nil
    end
    SearchableList.close(self)
end

function FilePicker:__tostring()
    return string.format('FilePicker(%d files)', #self._files)
end

return FilePicker
