-- GitSigns Extension: git diff signs in the sign column.
-- Replaces gitsigns.nvim with an owned implementation using git diff + extmarks.
-- Provides: sign placement, hunk navigation, hunk preview/stage/reset, blame, diff stats.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Position = require 'ide.Position'
local Timer = require 'ide.Timer'

local GitSigns = Class('GitSigns', Extension)

---@class GitHunk
---@field type 'add'|'change'|'delete'
---@field old_start integer
---@field old_count integer
---@field new_start integer
---@field new_count integer
---@field lines string[]

function GitSigns:init()
    Extension.init(self, 'GitSigns')
    self._ns = Buffer.create_namespace('ide_git_signs')
    self._cache = {} ---@type table<integer, { hunks: GitHunk[], tick: integer }>
    self._debounce = nil
end

--- Parse unified diff output into hunks.
---@param diff_output string
---@return GitHunk[]
function GitSigns.parse_diff(diff_output)
    local hunks = {}
    local current_hunk = nil
    local in_hunk = false

    for line in diff_output:gmatch('[^\n]+') do
        local os, oc, ns, nc = line:match('^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@')
        if os then
            if current_hunk then hunks[#hunks + 1] = current_hunk end
            local old_start = tonumber(os)
            local old_count = tonumber(oc) or 1
            local new_start = tonumber(ns)
            local new_count = tonumber(nc) or 1

            local htype = 'change'
            if old_count == 0 then htype = 'add'
            elseif new_count == 0 then htype = 'delete' end

            current_hunk = {
                type = htype,
                old_start = old_start,
                old_count = old_count,
                new_start = new_start,
                new_count = new_count,
                lines = {},
            }
            in_hunk = true
        elseif in_hunk and (line:sub(1, 1) == '+' or line:sub(1, 1) == '-' or line:sub(1, 1) == ' ') then
            current_hunk.lines[#current_hunk.lines + 1] = line
        end
    end
    if current_hunk then hunks[#hunks + 1] = current_hunk end

    return hunks
end

--- Get the sign icon for a hunk type.
---@param htype string
---@return string, string # sign_text, hl_group
local function sign_for_type(htype)
    if htype == 'add' then return '▎', 'GitSignsAdd'
    elseif htype == 'delete' then return '▁', 'GitSignsDelete'
    else return '▎', 'GitSignsChange'
    end
end

--- Run git diff for a buffer and update signs.
---@param bufnr integer
function GitSigns:_update_buffer(bufnr)
    if not Buffer.is_valid(bufnr) then return end
    local buf = Buffer.get(bufnr)
    if not buf:is_normal() then return end
    local path = buf:path()
    if not path then return end

    local cwd = IDE.git:root()
    if not cwd then return end

    local result = IDE.shell:run_sync('git', { 'diff', '--no-ext-diff', '-U0', '--', path }, { cwd = cwd, timeout = 3000 })
    if result.code ~= 0 then
        self._cache[bufnr] = { hunks = {}, tick = buf:changedtick() }
        self:_clear_signs(bufnr)
        self:_update_status_dict(bufnr, {})
        return
    end

    local hunks = GitSigns.parse_diff(result.stdout)
    self._cache[bufnr] = { hunks = hunks, tick = buf:changedtick() }
    self:_place_signs(bufnr, hunks)
    self:_update_status_dict(bufnr, hunks)
end

--- Place sign extmarks for hunks.
---@param bufnr integer
---@param hunks GitHunk[]
function GitSigns:_place_signs(bufnr, hunks)
    if not Buffer.is_valid(bufnr) then return end
    local buf = Buffer.get(bufnr)
    buf:clear_extmarks(self._ns)

    for _, hunk in ipairs(hunks) do
        local sign_text, sign_hl = sign_for_type(hunk.type)

        if hunk.type == 'delete' then
            local row = math.max(0, hunk.new_start - 1)
            pcall(function()
                buf:set_extmark(self._ns, row, 0, {
                    sign_text = sign_text,
                    sign_hl_group = sign_hl,
                    priority = 10,
                })
            end)
        else
            for i = 0, hunk.new_count - 1 do
                local row = hunk.new_start - 1 + i
                pcall(function()
                    buf:set_extmark(self._ns, row, 0, {
                        sign_text = sign_text,
                        sign_hl_group = sign_hl,
                        priority = 10,
                    })
                end)
            end
        end
    end
end

---@param bufnr integer
function GitSigns:_clear_signs(bufnr)
    if Buffer.is_valid(bufnr) then
        Buffer.get(bufnr):clear_extmarks(self._ns)
    end
end

--- Update vim.b.gitsigns_status_dict for statusline compatibility.
---@param bufnr integer
---@param hunks GitHunk[]
function GitSigns:_update_status_dict(bufnr, hunks)
    local added, changed, removed = 0, 0, 0
    for _, h in ipairs(hunks) do
        if h.type == 'add' then added = added + h.new_count
        elseif h.type == 'delete' then removed = removed + h.old_count
        else changed = changed + h.new_count end
    end
    pcall(function()
        Buffer.get(bufnr):set_var('gitsigns_status_dict', { added = added, changed = changed, removed = removed })
    end)
end

--- Get hunks for a buffer.
---@param bufnr integer
---@return GitHunk[]
function GitSigns:get_hunks(bufnr)
    local cached = self._cache[bufnr]
    return cached and cached.hunks or {}
end

--- Get diff counts for a buffer.
---@param bufnr integer
---@return { added: integer, changed: integer, removed: integer }
function GitSigns:diff_counts(bufnr)
    local hunks = self:get_hunks(bufnr)
    local added, changed, removed = 0, 0, 0
    for _, h in ipairs(hunks) do
        if h.type == 'add' then added = added + h.new_count
        elseif h.type == 'delete' then removed = removed + h.old_count
        else changed = changed + h.new_count end
    end
    return { added = added, changed = changed, removed = removed }
end

--- Navigate to next hunk.
function GitSigns:next_hunk()
    local bufnr = Buffer.current():id()
    local hunks = self:get_hunks(bufnr)
    if #hunks == 0 then return end

    local cursor_row = Window.current():cursor().row
    for _, h in ipairs(hunks) do
        if h.new_start > cursor_row then
            Window.current():set_cursor(Position(h.new_start, 1))
            return
        end
    end
    Window.current():set_cursor(Position(hunks[1].new_start, 1))
end

--- Navigate to previous hunk.
function GitSigns:prev_hunk()
    local bufnr = Buffer.current():id()
    local hunks = self:get_hunks(bufnr)
    if #hunks == 0 then return end

    local cursor_row = Window.current():cursor().row
    for i = #hunks, 1, -1 do
        if hunks[i].new_start < cursor_row then
            Window.current():set_cursor(Position(hunks[i].new_start, 1))
            return
        end
    end
    Window.current():set_cursor(Position(hunks[#hunks].new_start, 1))
end

--- Preview the hunk at cursor inline.
function GitSigns:preview_hunk_inline()
    local bufnr = Buffer.current():id()
    local hunk = self:_hunk_at_cursor(bufnr)
    if not hunk then
        IDE.ui:info('No hunk at cursor')
        return
    end

    local removed = {}
    for _, line in ipairs(hunk.lines) do
        if line:sub(1, 1) == '-' then
            removed[#removed + 1] = { { line:sub(2), 'DiffDelete' } }
        end
    end

    if #removed > 0 then
        local row = hunk.type == 'delete' and hunk.new_start - 1 or hunk.new_start - 1
        pcall(function()
            Buffer.get(bufnr):set_extmark(self._ns, math.max(0, row), 0, {
                virt_lines = removed,
                virt_lines_above = hunk.type ~= 'delete',
            })
        end)
    end
end

--- Reset the hunk at cursor.
function GitSigns:reset_hunk()
    local bufnr = Buffer.current():id()
    local hunk = self:_hunk_at_cursor(bufnr)
    if not hunk then
        IDE.ui:info('No hunk at cursor')
        return
    end

    local path = Buffer.get(bufnr):path()
    if not path then return end
    local cwd = IDE.git:root()
    if not cwd then return end

    local old_lines = {}
    for _, line in ipairs(hunk.lines) do
        if line:sub(1, 1) == '-' or line:sub(1, 1) == ' ' then
            old_lines[#old_lines + 1] = line:sub(2)
        end
    end

    local buf = Buffer.get(bufnr)
    buf:set_option('modifiable', true)
    if hunk.type == 'add' then
        buf:set_lines(hunk.new_start - 1, hunk.new_start - 1 + hunk.new_count, {})
    elseif hunk.type == 'delete' then
        buf:set_lines(hunk.new_start, hunk.new_start, old_lines)
    else
        buf:set_lines(hunk.new_start - 1, hunk.new_start - 1 + hunk.new_count, old_lines)
    end

    self:_schedule_update(bufnr)
end

--- Stage the hunk at cursor.
function GitSigns:stage_hunk()
    local bufnr = Buffer.current():id()
    local hunk = self:_hunk_at_cursor(bufnr)
    if not hunk then
        IDE.ui:info('No hunk at cursor')
        return
    end

    local path = Buffer.get(bufnr):path()
    if not path then return end
    local cwd = IDE.git:root()
    if not cwd then return end
    local rel_path = IDE.fs:relative_path(cwd, path)

    local patch = self:_build_patch(rel_path, hunk)
    local result = IDE.shell:run_sync('git', { 'apply', '--cached', '--recount', '-' }, { cwd = cwd, stdin = patch })
    if result.code == 0 then
        self:_schedule_update(bufnr)
        IDE.ui:info('Hunk staged')
    else
        IDE.ui:error('Failed to stage hunk: ' .. result.stderr)
    end
end

--- Stage the entire buffer.
function GitSigns:stage_buffer()
    local buf = Buffer.current()
    local path = buf and buf:path()
    if not path then return end
    local cwd = IDE.git:root()
    if not cwd then return end
    local result = IDE.shell:run_sync('git', { 'add', path }, { cwd = cwd })
    if result.code == 0 then
        self:_schedule_update(buf:id())
        IDE.ui:info('Buffer staged')
    else
        IDE.ui:error('Failed to stage buffer: ' .. result.stderr)
    end
end

--- Reset the entire buffer to HEAD.
function GitSigns:reset_buffer()
    local buf = Buffer.current()
    local path = buf and buf:path()
    if not path then return end
    local cwd = IDE.git:root()
    if not cwd then return end
    local result = IDE.shell:run_sync('git', { 'checkout', '--', path }, { cwd = cwd })
    if result.code == 0 then
        IDE.buffers:current():reload()
        IDE.ui:info('Buffer reset')
    else
        IDE.ui:error('Failed to reset buffer: ' .. result.stderr)
    end
end

--- Undo the last staged hunk by reverse-applying the cached patch.
function GitSigns:undo_stage_hunk()
    local bufnr = Buffer.current():id()
    local path = Buffer.get(bufnr):path()
    if not path then return end
    local cwd = IDE.git:root()
    if not cwd then return end
    local rel_path = IDE.fs:relative_path(cwd, path)

    -- Get the staged diff so we can reverse-apply it
    local result = IDE.shell:run_sync('git', { 'diff', '--cached', '--no-ext-diff', '-U0', '--', path }, { cwd = cwd })
    if result.code ~= 0 or result.stdout == '' then
        IDE.ui:info('No staged hunks to undo')
        return
    end

    -- Parse staged hunks and find the last one
    local staged_hunks = GitSigns.parse_diff(result.stdout)
    if #staged_hunks == 0 then
        IDE.ui:info('No staged hunks to undo')
        return
    end

    local last_hunk = staged_hunks[#staged_hunks]
    local patch = self:_build_patch(rel_path, last_hunk)
    local apply_result = IDE.shell:run_sync('git', { 'apply', '--cached', '--reverse', '--recount', '-' }, { cwd = cwd, stdin = patch })
    if apply_result.code == 0 then
        self:_schedule_update(bufnr)
        IDE.ui:info('Hunk unstaged')
    else
        IDE.ui:error('Failed to unstage hunk: ' .. apply_result.stderr)
    end
end

--- Select the hunk at cursor in visual mode (linewise).
function GitSigns:select_hunk()
    local bufnr = Buffer.current():id()
    local hunk = self:_hunk_at_cursor(bufnr)
    if not hunk or hunk.type == 'delete' then
        IDE.ui:info('No selectable hunk at cursor')
        return
    end
    local start_line = hunk.new_start
    local end_line = hunk.new_start + math.max(hunk.new_count, 1) - 1
    local win = Window.current()
    win:set_cursor(Position(start_line, 1))
    win:select_line()
    win:set_cursor(Position(end_line, 1))
end

--- Show diff for the current file.
function GitSigns:diff_this()
    local buf = Buffer.current()
    local path = buf and buf:path()
    if not path then return end
    local cwd = IDE.git:root()
    if not cwd then return end
    vim.cmd('diffsplit ' .. vim.fn.fnameescape(path))
end

function GitSigns:blame_line()
    local bufnr = Buffer.current():id()
    local path = Buffer.get(bufnr):path()
    if not path then return end
    local cwd = IDE.git:root()
    if not cwd then return end

    local cursor_row = Window.current():cursor().row
    local result = IDE.shell:run_sync('git', { 'blame', '-L', cursor_row .. ',' .. cursor_row, '--porcelain', path }, { cwd = cwd })
    if result.code ~= 0 then return end

    local author, summary, date
    for line in result.stdout:gmatch('[^\n]+') do
        if line:match('^author ') then author = line:sub(8) end
        if line:match('^summary ') then summary = line:sub(9) end
        if line:match('^author%-time ') then
            date = os.date('%Y-%m-%d', tonumber(line:sub(13)))
        end
    end

    if author and summary then
        IDE.ui:info(string.format('%s (%s): %s', author, date or '?', summary), { title = 'Git Blame' })
    end
end

--- Find the hunk at the current cursor position.
---@param bufnr integer
---@return GitHunk|nil
function GitSigns:_hunk_at_cursor(bufnr)
    local hunks = self:get_hunks(bufnr)
    local row = Window.current():cursor().row
    for _, h in ipairs(hunks) do
        if h.type == 'delete' then
            if row == h.new_start or row == h.new_start + 1 then return h end
        else
            if row >= h.new_start and row < h.new_start + h.new_count then return h end
        end
    end
    return nil
end

--- Build a patch string for git apply.
---@param rel_path string
---@param hunk GitHunk
---@return string
function GitSigns:_build_patch(rel_path, hunk)
    local lines = {
        string.format('--- a/%s', rel_path),
        string.format('+++ b/%s', rel_path),
        string.format('@@ -%d,%d +%d,%d @@', hunk.old_start, hunk.old_count, hunk.new_start, hunk.new_count),
    }
    for _, l in ipairs(hunk.lines) do
        lines[#lines + 1] = l
    end
    lines[#lines + 1] = ''
    return table.concat(lines, '\n')
end

--- Schedule a debounced update for a buffer.
---@param bufnr integer
function GitSigns:_schedule_update(bufnr)
    if not self._debounce then
        self._debounce = Timer.debounce(300, function()
            local cur = Buffer.current():id()
            if Buffer.is_valid(cur) then
                self:_update_buffer(cur)
            end
        end)
    end
    self._debounce()
end

function GitSigns:on_register(ctx)
    if not IDE.shell:has('git') then return end

    local ext = self

    IDE.theme:define('GitSignsAdd', { fg = '#9ece6a', default = true })
    IDE.theme:define('GitSignsChange', { fg = '#e0af68', default = true })
    IDE.theme:define('GitSignsDelete', { fg = '#f7768e', default = true })
    IDE.theme:define('GitSignsTopDelete', { fg = '#f7768e', default = true })
    IDE.theme:define('GitSignsChangeDelete', { fg = '#e0af68', default = true })
    IDE.theme:define('GitSignsUntracked', { fg = '#565f89', default = true })

    ctx:hook({ 'BufReadPost', 'BufWritePost', 'FocusGained' }, function(args)
        if Buffer.is_valid(args.buf) and Buffer.get(args.buf):is_normal() then
            ext:_update_buffer(args.buf)
        end
    end, { desc = 'GitSigns: update on file events' })

    ctx:hook('TextChanged', function(args)
        ext:_schedule_update(args.buf)
    end, { desc = 'GitSigns: schedule update on text change' })

    -- Register git actions for command palette discovery
    ctx:action('git.nextHunk', 'Next git hunk', function() ext:next_hunk() end)
    ctx:action('git.prevHunk', 'Previous git hunk', function() ext:prev_hunk() end)
    ctx:action('git.resetHunk', 'Reset hunk', function() ext:reset_hunk() end)
    ctx:action('git.previewHunk', 'Preview hunk', function() ext:preview_hunk_inline() end)
    ctx:action('git.stageHunk', 'Stage hunk', function() ext:stage_hunk() end)
    ctx:action('git.undoStage', 'Undo stage hunk', function() ext:undo_stage_hunk() end)
    ctx:action('git.blameLine', 'Blame line', function() ext:blame_line() end)
    ctx:action('git.selectHunk', 'Select hunk', function() ext:select_hunk() end)
    ctx:action('git.stageBuffer', 'Stage buffer', function() ext:stage_buffer() end)
    ctx:action('git.resetBuffer', 'Reset buffer', function() ext:reset_buffer() end)
    ctx:action('git.diffThis', 'Diff current file', function() ext:diff_this() end)

    ctx:keymap('n', ']h', 'git.nextHunk', { desc = 'Next git hunk' })
    ctx:keymap('n', '[h', 'git.prevHunk', { desc = 'Previous git hunk' })
    ctx:keymap('n', 'ghr', 'git.resetHunk', { desc = 'Reset hunk' })
    ctx:keymap('n', 'ghh', 'git.previewHunk', { desc = 'Preview hunk' })
    ctx:keymap('n', 'ghs', 'git.stageHunk', { desc = 'Stage hunk' })
    ctx:keymap('n', 'ghu', 'git.undoStage', { desc = 'Undo stage hunk' })
    ctx:keymap('n', 'ghb', 'git.blameLine', { desc = 'Blame line' })
    ctx:keymap('n', 'ghx', 'git.selectHunk', { desc = 'Select hunk' })
    ctx:keymap('n', 'ghS', 'git.stageBuffer', { desc = 'Stage buffer' })
    ctx:keymap('n', 'ghR', 'git.resetBuffer', { desc = 'Reset buffer' })

    IDE.keys:group('gh', { desc = 'Git hunks', icon = '' })

    Buffer.add_context_provider(function(buf, row)
        local hunks = ext:get_hunks(buf:id())
        if not hunks or #hunks == 0 then return nil end
        for _, hunk in ipairs(hunks) do
            local hunk_start = hunk.new_start
            local hunk_end = hunk.type == 'delete' and hunk_start + 1 or hunk_start + math.max(hunk.new_count, 1)
            if row >= hunk_start and row < hunk_end then
                return {{ group = 'Git', items = {
                    { text = 'Preview Hunk', icon = '', action = function() ext:preview_hunk_inline() end },
                    { text = 'Reset Hunk', icon = '󰜺', action = function() ext:reset_hunk() end },
                    { text = 'Stage Hunk', icon = '', action = function() ext:stage_hunk() end },
                    { text = 'Undo Stage Hunk', icon = '󰕌', action = function() ext:undo_stage_hunk() end },
                    { text = 'Select Hunk', icon = '󰒉', action = function() ext:select_hunk() end },
                    { text = 'Blame Line', icon = '', action = function() ext:blame_line() end },
                }}}
            end
        end
        return nil
    end)

    ctx:notify('Git signs active')
end

return GitSigns
