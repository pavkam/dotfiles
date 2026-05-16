-- GrepPicker: TurboVision-style live grep dialog.
-- Extends SearchableList with debounced ripgrep search.

local SearchableList = require 'ide.toolkit.SearchableList'
local Buffer = require 'ide.Buffer'

local GrepPicker = Class('GrepPicker', SearchableList)

---@param opts { title?: string, cwd?: string, search?: string, on_select?: fun(path: string, line: integer) }
function GrepPicker:init(opts)
    opts = opts or {}
    SearchableList.init(self, {
        title = opts.title or '  Search',
        width = 0.7,
        height = 0.6,
        preview = true,
    })
    self._cwd = opts.cwd or (IDE and IDE.git:root()) or (IDE and IDE.fs:cwd()) or vim.fn.getcwd()
    self._ext_on_select = opts.on_select
    self._query = opts.search or ''
    self._results = {}
    self._search_handle = nil
    self._search_timer = nil
end

function GrepPicker:items()
    return self._results
end

function GrepPicker:total_count()
    return #self._results
end

function GrepPicker:on_query_change(query)
    -- Debounced: schedule rg after 150ms pause
    if self._search_timer then
        pcall(self._search_timer.stop, self._search_timer)
        pcall(self._search_timer.close, self._search_timer)
    end
    if query == '' then
        self._results = {}
        self._selected = 1
        self._scroll = 0
        return
    end
    self._search_timer = vim.uv.new_timer()
    self._search_timer:start(150, 0, vim.schedule_wrap(function()
        self._search_timer = nil
        self:_search()
    end))
end

function GrepPicker:_search()
    if self._search_handle then
        pcall(self._search_handle.kill, self._search_handle)
        self._search_handle = nil
    end
    if self._query == '' then return end

    local args = { '--vimgrep', '--no-heading', '--smart-case', '--fixed-strings', '--hidden', '--glob', '!.git/', '--max-count=200', self._query, self._cwd }
    local gp = self

    self._search_handle = IDE.shell:run('rg', args, { cwd = self._cwd }, function(result)
        gp._search_handle = nil
        gp._results = {}
        local prefix = gp._cwd .. '/'
        for line in (result.stdout or ''):gmatch('[^\n]+') do
            local path, lnum, col, text = line:match('^(.+):(%d+):(%d+):(.*)$')
            if path then
                local rel = path
                if path:sub(1, #prefix) == prefix then rel = path:sub(#prefix + 1) end
                gp._results[#gp._results + 1] = {
                    path = path, rel = rel, lnum = tonumber(lnum), col = tonumber(col), text = vim.trim(text),
                }
            end
        end
        gp._selected = #gp._results > 0 and 1 or 0
        gp._scroll = 0
        if gp._mounted then gp:_render() end
    end)
end

function GrepPicker:preview_path(item)
    return { path = item.path, line = item.lnum }
end

function GrepPicker:render_item(item, width)
    return {
        { type = 'text', text = item.rel, hl = 'Directory' },
        { type = 'text', text = ':' .. item.lnum .. ': ', hl = 'LineNr' },
        { type = 'text', text = item.text },
    }
end

function GrepPicker:on_submit(item)
    self:close()
    vim.schedule(function()
        Buffer.open(item.path)
        pcall(vim.api.nvim_win_set_cursor, 0, { item.lnum, item.col - 1 })
        if self._ext_on_select then self._ext_on_select(item.path, item.lnum) end
    end)
end

function GrepPicker:close()
    if self._search_handle then
        pcall(self._search_handle.kill, self._search_handle)
        self._search_handle = nil
    end
    if self._search_timer then
        pcall(self._search_timer.stop, self._search_timer)
        pcall(self._search_timer.close, self._search_timer)
        self._search_timer = nil
    end
    SearchableList.close(self)
end

function GrepPicker:__tostring()
    return string.format('GrepPicker(%d results)', #self._results)
end

return GrepPicker
