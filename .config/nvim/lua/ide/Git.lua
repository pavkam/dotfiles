-- Git: git integration abstraction.
-- Wraps git commands and gitsigns into a clean API.

local Git = Class('Git')

function Git:init(shell)
    self._shell = shell
end

--- Get the current branch name.
---@param cwd string|nil
---@return string|nil
function Git:branch(cwd)
    local r = self._shell:run_sync('git', { 'branch', '--show-current' }, { cwd = cwd })
    if r.code == 0 then
        return vim.trim(r.stdout)
    end
    return nil
end

--- Check if a file is tracked by git.
---@param path string
---@return boolean
function Git:is_tracked(path)
    local dir = vim.fs.dirname(path)
    local r = self._shell:run_sync('git', { 'ls-files', '--error-unmatch', path }, { cwd = dir })
    return r.code == 0
end

--- Get the status of the working tree.
---@param cwd string|nil
---@return { modified: integer, added: integer, deleted: integer }
function Git:status_counts(cwd)
    local r = self._shell:run_sync('git', { 'diff', '--numstat' }, { cwd = cwd })
    local modified, added, deleted = 0, 0, 0
    if r.code == 0 then
        for line in r.stdout:gmatch('[^\n]+') do
            local a, d = line:match('^(%d+)%s+(%d+)')
            if a then
                added = added + tonumber(a)
                deleted = deleted + tonumber(d)
                modified = modified + 1
            end
        end
    end
    return { modified = modified, added = added, deleted = deleted }
end

--- Get the root of the git repository.
---@param cwd string|nil
---@return string|nil
function Git:root(cwd)
    local r = self._shell:run_sync('git', { 'rev-parse', '--show-toplevel' }, { cwd = cwd })
    if r.code == 0 then
        return vim.trim(r.stdout)
    end
    return nil
end

--- Check if we're inside a git repo.
---@param cwd string|nil
---@return boolean
function Git:is_repo(cwd)
    return self:root(cwd) ~= nil
end

--- Get recent commits.
---@param opts { count?: integer, cwd?: string }|nil
---@return { hash: string, subject: string, author: string }[]
function Git:log(opts)
    opts = opts or {}
    local count = opts.count or 10
    local r = self._shell:run_sync('git', {
        'log', '--oneline', '--format=%h|%s|%an', '-' .. count
    }, { cwd = opts.cwd })

    local result = {}
    if r.code == 0 then
        for line in r.stdout:gmatch('[^\n]+') do
            local hash, subject, author = line:match('^([^|]+)|([^|]+)|(.+)$')
            if hash then
                result[#result + 1] = { hash = hash, subject = subject, author = author }
            end
        end
    end
    return result
end

--- Get per-file git status for all files in the working tree.
---@param cwd string|nil
---@return table<string, string> # { [absolute_path] = status_code } where status is M/A/D/R/?/!
function Git:status_map(cwd)
    cwd = cwd or self:root() or vim.uv.cwd()
    local r = self._shell:run_sync('git', { 'status', '--porcelain', '-u' }, { cwd = cwd })
    local map = {}
    if r.code == 0 then
        for line in r.stdout:gmatch('[^\n]+') do
            local status = line:sub(1, 2):gsub('%s', '')
            local file = line:sub(4)
            if file and file ~= '' then
                local abs = vim.fs.joinpath(cwd, file)
                map[abs] = status:sub(1, 1) == '?' and '?' or status:sub(1, 1)
            end
        end
    end
    return map
end

--- Get git status for a single file.
---@param path string
---@return string|nil # status code (M/A/D/R/?/!) or nil if clean/untracked
function Git:file_status(path)
    local root = self:root(vim.fs.dirname(path))
    if not root then return nil end
    local map = self:status_map(root)
    return map[path] or map[vim.uv.fs_realpath(path) or path]
end

--- Check if a file is ignored by .gitignore.
---@param path string
---@return boolean
function Git:is_ignored(path)
    local r = self._shell:run_sync('git', { 'check-ignore', '-q', path }, { cwd = vim.fs.dirname(path) })
    return r.code == 0
end

-- Hunk operations — delegate to GitSigns extension

--- Navigate to next hunk.
function Git:next_hunk()
    local ext = IDE:extension('GitSigns')
    if ext then ext:next_hunk() end
end

--- Navigate to previous hunk.
function Git:prev_hunk()
    local ext = IDE:extension('GitSigns')
    if ext then ext:prev_hunk() end
end

--- Preview the current hunk inline.
function Git:preview_hunk()
    local ext = IDE:extension('GitSigns')
    if ext then ext:preview_hunk_inline() end
end

--- Stage the current hunk.
function Git:stage_hunk()
    local ext = IDE:extension('GitSigns')
    if ext then ext:stage_hunk() end
end

--- Reset the current hunk.
function Git:reset_hunk()
    local ext = IDE:extension('GitSigns')
    if ext then ext:reset_hunk() end
end

--- Undo the last staged hunk.
function Git:undo_stage_hunk()
    local ext = IDE:extension('GitSigns')
    if ext then ext:undo_stage_hunk() end
end

--- Stage the entire buffer.
function Git:stage_buffer()
    local ext = IDE:extension('GitSigns')
    if ext then ext:stage_buffer() end
end

--- Reset the entire buffer to HEAD.
function Git:reset_buffer()
    local ext = IDE:extension('GitSigns')
    if ext then ext:reset_buffer() end
end

--- Select the hunk at cursor in visual mode.
function Git:select_hunk()
    local ext = IDE:extension('GitSigns')
    if ext then ext:select_hunk() end
end

--- Blame the current line.
function Git:blame_line()
    local ext = IDE:extension('GitSigns')
    if ext then ext:blame_line() end
end

--- Show diff for the current file.
function Git:diff_this()
    local ext = IDE:extension('GitSigns')
    if ext then ext:diff_this() end
end

--- Open lazygit in a floating terminal.
function Git:lazygit()
    if self._shell:has('lazygit') then
        self._shell:floating('lazygit')
    end
end

---@return string
function Git:__tostring()
    local branch = self:branch()
    return string.format('Git(%s)', branch or 'not a repo')
end

return Git
