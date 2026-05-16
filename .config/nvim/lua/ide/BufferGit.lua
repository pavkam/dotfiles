-- BufferGit: per-buffer git status facade.
-- Accessed via buf:git(). Wraps git operations scoped to a specific buffer.

local BufferGit = Class('BufferGit')

---@param bufnr integer
function BufferGit:init(bufnr)
    self._bufnr = bufnr
end

--- Get the git diff hunks for this buffer (from git_signs extension cache).
---@return table[] # list of hunk objects { type, old_start, old_count, new_start, new_count }
function BufferGit:hunks()
    local ext = IDE and IDE:extension('GitSigns')
    if ext and ext.get_hunks then
        return ext:get_hunks(self._bufnr)
    end
    return {}
end

--- Get the diff summary (added/changed/removed line counts).
---@return { added: integer, changed: integer, removed: integer }
function BufferGit:diff_summary()
    local Buffer = require 'ide.Buffer'
    if not Buffer.is_valid(self._bufnr) then
        return { added = 0, changed = 0, removed = 0 }
    end
    local dict = Buffer(self._bufnr):var('gitsigns_status_dict')
    if dict then
        return { added = dict.added or 0, changed = dict.changed or 0, removed = dict.removed or 0 }
    end
    return { added = 0, changed = 0, removed = 0 }
end

--- Check if this buffer's file is tracked by git.
---@return boolean
function BufferGit:is_tracked()
    if self._tracked ~= nil then return self._tracked end
    local Buffer = require 'ide.Buffer'
    if not Buffer.is_valid(self._bufnr) then return false end
    local path = Buffer.get(self._bufnr):path()
    if not path then return false end
    local result = IDE.shell:run_sync('git', { 'ls-files', '--error-unmatch', path }, { timeout = 500 })
    self._tracked = result.code == 0
    return self._tracked
end

--- Invalidate cached tracking state (e.g. after file write).
function BufferGit:invalidate()
    self._tracked = nil
end

---@return string
function BufferGit:__tostring()
    local s = self:diff_summary()
    return string.format('BufferGit(buf=%d, +%d ~%d -%d)', self._bufnr, s.added, s.changed, s.removed)
end

return BufferGit
