-- FileTree: TurboVision-style file explorer panel.
-- Shows a directory tree with expand/collapse, icons, git status.
-- Rendered as a bordered floating panel on the left side.

local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Shadow = require 'ide.toolkit.Shadow'

local FileTree = Class('FileTree')

---@class FileTreeOpts
---@field cwd? string
---@field width? integer
---@field on_select? fun(path: string)

---@param opts? FileTreeOpts
function FileTree:init(opts)
    opts = opts or {}
    self._cwd = opts.cwd or (IDE and IDE.git:root()) or vim.fn.getcwd()
    self._width = opts.width or 35
    self._on_select = opts.on_select
    self._buf = nil
    self._win = nil
    self._shadow = nil
    self._mounted = false
    self._ns = nil
    self._tree = {}     -- flat list of visible nodes
    self._expanded = {} -- path → true for expanded dirs
    self._selected = 1
    self._expanded[self._cwd] = true
    self._show_hidden = false
    self._clipboard = nil -- { path: string, op: 'copy'|'cut' }
end

---@class FileTreeNode
---@field name string
---@field path string
---@field is_dir boolean
---@field depth integer
---@field icon? string
---@field icon_hl? string

-- Always-ignored entries (not toggleable).
local IGNORED = { ['.git'] = true, ['node_modules'] = true, ['__pycache__'] = true, ['.DS_Store'] = true }

--- Scan a directory and return sorted entries (dirs first, then files).
---@param dir string
---@param show_hidden boolean
---@return { name: string, path: string, is_dir: boolean }[]
local function scan_dir(dir, show_hidden)
    local entries = {}
    local handle = vim.uv.fs_scandir(dir)
    if not handle then return entries end

    while true do
        local name, typ = vim.uv.fs_scandir_next(handle)
        if not name then break end
        if not IGNORED[name] then
            -- Hide dotfiles unless show_hidden is on
            if show_hidden or name:sub(1, 1) ~= '.' then
                local path = dir .. '/' .. name
                local is_dir = typ == 'directory'
                if not is_dir and typ == 'link' then
                    local stat = vim.uv.fs_stat(path)
                    is_dir = stat and stat.type == 'directory'
                end
                entries[#entries + 1] = { name = name, path = path, is_dir = is_dir }
            end
        end
    end

    table.sort(entries, function(a, b)
        if a.is_dir ~= b.is_dir then return a.is_dir end
        return a.name < b.name
    end)
    return entries
end

--- Build the flat visible tree from expanded state.
function FileTree:_build_tree()
    self._tree = {}

    local show_hidden = self._show_hidden
    local function walk(dir, depth)
        local entries = scan_dir(dir, show_hidden)
        for _, entry in ipairs(entries) do
            local icon, icon_hl = '', 'IDEMenuIcon'
            if entry.is_dir then
                icon = self._expanded[entry.path] and '' or ''
                icon_hl = 'Directory'
            elseif IDE and IDE.icons and IDE.icons:is_loaded() then
                local fname = vim.fn.fnamemodify(entry.path, ':t')
                local ext = vim.fn.fnamemodify(entry.path, ':e')
                local ic = IDE.icons:for_file(fname, ext)
                if ic then icon = ic:char() end
            end

            self._tree[#self._tree + 1] = {
                name = entry.name,
                path = entry.path,
                is_dir = entry.is_dir,
                depth = depth,
                icon = icon,
                icon_hl = icon_hl,
            }

            if entry.is_dir and self._expanded[entry.path] then
                walk(entry.path, depth + 1)
            end
        end
    end

    walk(self._cwd, 0)
end

function FileTree:show()
    if self._mounted then self:close() end

    self:_build_tree()

    local eh = Window.editor_height()
    local width = self._width
    local height = eh - 5  -- below tabline, above statusline
    local row = 2  -- below tabline + frame title
    local col = 1  -- inside left frame border

    self._shadow = Shadow.for_float(row, col, width + 2, height + 2, 199)

    self._buf = Buffer.create({ listed = false, scratch = true })
    self._buf:set_option('bufhidden', 'wipe')
    self._buf:set_option('filetype', 'ide-filetree')

    self._win = Window.open_float(self._buf, {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        border = { '╔', '═', '╗', '║', '╝', '═', '╚', '║' },
        title = { { '[■]', 'IDEWinButton' }, { '═', 'IDEDialogBorder' }, { ' File Explorer ', 'IDEDialogTitle' } },
        title_pos = 'left',
        style = 'minimal',
        zindex = 200,
        enter = true,
    })
    self._mounted = true
    self._ns = Buffer.create_namespace('ide_filetree')

    self._win:set_option('cursorline', false)
    self._win:set_option('wrap', false)
    self._win:set_option('winhl', 'Normal:IDEDialogNormal,FloatBorder:IDEDialogBorder')
    self._win:set_option('winblend', 0)

    self:_render()
    self:_bind_keys()
end

function FileTree:_render()
    if not self._buf or not self._buf:is_valid() then return end

    local width = self._win:width()
    local lines = {}

    for _, node in ipairs(self._tree) do
        local indent = string.rep('  ', node.depth)
        local connector = ''
        if node.depth > 0 then
            connector = '├─'
        end
        local icon_part = node.icon ~= '' and (node.icon .. ' ') or '  '
        local suffix = node.is_dir and '/' or ''
        local line = indent .. connector .. icon_part .. node.name .. suffix
        if #line < width then line = line .. string.rep(' ', width - #line) end
        if #line > width then line = line:sub(1, width) end
        lines[#lines + 1] = line
    end

    if #lines == 0 then
        lines[#lines + 1] = '  (empty)'
    end

    self._buf:set_option('modifiable', true)
    self._buf:set_lines(0, -1, lines)

    vim.api.nvim_buf_clear_namespace(self._buf:id(), self._ns, 0, -1)

    -- Highlight selected line
    if self._selected >= 1 and self._selected <= #self._tree then
        vim.api.nvim_buf_add_highlight(self._buf:id(), self._ns,
            'IDEDialogListSelected', self._selected - 1, 0, -1)
    end

    -- Highlight directories
    for i, node in ipairs(self._tree) do
        if node.is_dir then
            vim.api.nvim_buf_add_highlight(self._buf:id(), self._ns,
                'Directory', i - 1, 0, -1)
        end
    end

    -- Footer with path + status indicators
    local rel = vim.fn.fnamemodify(self._cwd, ':~')
    local footer_parts = { { ' ' .. rel .. ' ', 'IDEDialogTitle' } }
    if self._show_hidden then
        footer_parts[#footer_parts + 1] = { ' [H] ', 'WarningMsg' }
    end
    if self._clipboard then
        local clip_name = IDE and IDE.fs:basename(self._clipboard.path)
            or vim.fs.basename(self._clipboard.path)
        local op_label = self._clipboard.op == 'cut' and 'CUT' or 'COPY'
        footer_parts[#footer_parts + 1] = { ' [' .. op_label .. ': ' .. clip_name .. '] ', 'Special' }
    end
    pcall(function()
        self._win:update_config({ footer = footer_parts, footer_pos = 'left' })
    end)

    self._buf:set_option('modifiable', false)
end

function FileTree:_bind_keys()
    local ft = self
    local function map(key, fn)
        self._buf:bind_key('n', key, fn)
    end

    -- Navigation
    map('j', function() ft:_move(1) end)
    map('<Down>', function() ft:_move(1) end)
    map('k', function() ft:_move(-1) end)
    map('<Up>', function() ft:_move(-1) end)

    -- Expand/collapse
    map('l', function() ft:_expand() end)
    map('<Right>', function() ft:_expand() end)
    map('h', function() ft:_collapse() end)
    map('<Left>', function() ft:_collapse() end)

    -- Open file / toggle directory
    map('<CR>', function() ft:_activate() end)
    map('o', function() ft:_activate() end)

    -- Close
    map('<Esc>', function() ft:close() end)
    map('q', function() ft:close() end)

    -- Mouse click: select node, double-click activates
    local last_click_time = 0
    map('<LeftMouse>', function()
        local mpos = vim.fn.getmousepos()
        if not mpos then return end
        if mpos.winid == ft._win:id() and mpos.line > 0 and mpos.line <= #ft._tree then
            ft._selected = mpos.line
            ft:_render()
            if ft._win and ft._win:is_valid() then
                ft._win:set_cursor(require('ide.Position')(mpos.line, 1))
            end
            -- Double-click detection
            local now = vim.uv.now()
            if now - last_click_time < 300 then
                ft:_activate()
            end
            last_click_time = now
        else
            ft:close()
        end
    end)

    -- Refresh
    map('R', function()
        ft:_build_tree()
        ft:_render()
    end)

    -- Toggle hidden files
    map('H', function() ft:_toggle_hidden() end)

    -- Create file or directory (trailing / = directory)
    map('a', function() ft:_create() end)

    -- Delete file or directory
    map('d', function() ft:_delete() end)

    -- Rename file or directory
    map('r', function() ft:_rename() end)

    -- Copy path to clipboard
    map('y', function() ft:_yank_path() end)

    -- Copy file (mark for copy)
    map('c', function() ft:_copy_to_clipboard() end)

    -- Cut file (mark for move)
    map('x', function() ft:_cut_to_clipboard() end)

    -- Paste (copy or move the clipboard file)
    map('p', function() ft:_paste() end)

    -- Auto-close on focus loss (with delay to avoid closing on transient focus shifts)
    vim.api.nvim_create_autocmd('WinLeave', {
        buffer = ft._buf:id(),
        callback = function()
            vim.defer_fn(function()
                if not ft._mounted then return end
                if not ft._win or not ft._win:is_valid() then return end
                local cur_win = vim.api.nvim_get_current_win()
                if cur_win ~= ft._win:id() then
                    ft:close()
                end
            end, 100)
        end,
    })
end

function FileTree:_move(dir)
    if #self._tree == 0 then return end
    self._selected = self._selected + dir
    if self._selected < 1 then self._selected = #self._tree end
    if self._selected > #self._tree then self._selected = 1 end
    self:_render()
    if self._win and self._win:is_valid() then
        self._win:set_cursor(require('ide.Position')(self._selected, 1))
    end
end

function FileTree:_expand()
    local node = self._tree[self._selected]
    if not node or not node.is_dir then return end
    self._expanded[node.path] = true
    self:_build_tree()
    self:_render()
end

function FileTree:_collapse()
    local node = self._tree[self._selected]
    if not node then return end
    if node.is_dir and self._expanded[node.path] then
        self._expanded[node.path] = nil
        self:_build_tree()
        self:_render()
    elseif node.depth > 0 then
        -- Collapse parent directory
        local parent = vim.fn.fnamemodify(node.path, ':h')
        self._expanded[parent] = nil
        self:_build_tree()
        -- Move cursor to parent
        for i, n in ipairs(self._tree) do
            if n.path == parent then
                self._selected = i
                break
            end
        end
        self:_render()
    end
end

function FileTree:_activate()
    local node = self._tree[self._selected]
    if not node then return end

    if node.is_dir then
        -- Toggle expand
        if self._expanded[node.path] then
            self._expanded[node.path] = nil
        else
            self._expanded[node.path] = true
        end
        self:_build_tree()
        self:_render()
    else
        -- Open file
        local path = node.path
        self:close()
        if self._on_select then
            vim.schedule(function() self._on_select(path) end)
        else
            vim.schedule(function()
                require('ide.Buffer').open(path)
            end)
        end
    end
end

--- Get the directory context for the selected node.
--- If a file is selected, returns its parent directory.
--- If a directory is selected, returns that directory.
---@return string
function FileTree:_context_dir()
    local node = self._tree[self._selected]
    if not node then return self._cwd end
    if node.is_dir then return node.path end
    return IDE and IDE.fs:dirname(node.path) or vim.fs.dirname(node.path)
end

--- Refresh the tree, preserving selection as best as possible.
function FileTree:_refresh()
    local sel_path = self._tree[self._selected] and self._tree[self._selected].path
    self:_build_tree()

    -- Try to re-select the same path
    if sel_path then
        for i, node in ipairs(self._tree) do
            if node.path == sel_path then
                self._selected = i
                self:_render()
                if self._win and self._win:is_valid() then
                    self._win:set_cursor(require('ide.Position')(self._selected, 1))
                end
                return
            end
        end
    end

    -- Clamp selection
    if self._selected > #self._tree then
        self._selected = math.max(1, #self._tree)
    end
    self:_render()
    if self._win and self._win:is_valid() and #self._tree > 0 then
        self._win:set_cursor(require('ide.Position')(self._selected, 1))
    end
end

--- Select a node by path after a refresh.
---@param path string
function FileTree:_select_path(path)
    for i, node in ipairs(self._tree) do
        if node.path == path then
            self._selected = i
            self:_render()
            if self._win and self._win:is_valid() then
                self._win:set_cursor(require('ide.Position')(self._selected, 1))
            end
            return
        end
    end
    self:_render()
end

--- Toggle hidden files visibility.
function FileTree:_toggle_hidden()
    self._show_hidden = not self._show_hidden
    self:_refresh()
end

--- Create a new file or directory.
function FileTree:_create()
    local dir = self:_context_dir()
    local ft = self

    IDE.ui:input('New file (end with / for directory): ', function(name)
        if not name or name == '' then return end

        local path = IDE.fs:join(dir, name)

        if IDE.fs:exists(path) then
            IDE.ui:warn('Already exists: ' .. name)
            return
        end

        if name:sub(-1) == '/' then
            -- Create directory
            IDE.fs:mkdir(path:sub(1, -2))
            IDE.ui:info('Created directory: ' .. name)
        else
            -- Create file (mkdir -p for parent dirs)
            IDE.fs:write(path, '')
            IDE.ui:info('Created file: ' .. name)
        end

        -- Expand parent so the new entry is visible
        ft._expanded[dir] = true
        ft:_build_tree()
        ft:_select_path(name:sub(-1) == '/' and path:sub(1, -2) or path)
    end)
end

--- Delete the selected file or directory.
function FileTree:_delete()
    local node = self._tree[self._selected]
    if not node then return end

    local name = IDE and IDE.fs:basename(node.path) or vim.fs.basename(node.path)
    local label = node.is_dir and ('directory "' .. name .. '"') or ('"' .. name .. '"')
    local ft = self

    IDE.ui:confirm('Delete ' .. label .. '?', function(yes)
        if not yes then return end

        local ok, err
        if node.is_dir then
            ok, err = IDE.fs:delete_recursive(node.path)
        else
            ok, err = IDE.fs:delete(node.path)
        end

        if not ok then
            IDE.ui:error('Delete failed: ' .. (err or 'unknown error'))
            return
        end

        -- Clear clipboard if it references the deleted path
        if ft._clipboard and ft._clipboard.path == node.path then
            ft._clipboard = nil
        end

        IDE.ui:info('Deleted: ' .. name)
        ft:_refresh()
    end)
end

--- Rename the selected file or directory.
function FileTree:_rename()
    local node = self._tree[self._selected]
    if not node then return end

    local old_name = IDE and IDE.fs:basename(node.path) or vim.fs.basename(node.path)
    local dir = IDE and IDE.fs:dirname(node.path) or vim.fs.dirname(node.path)
    local ft = self

    IDE.ui:input('Rename: ', function(new_name)
        if not new_name or new_name == '' or new_name == old_name then return end

        local new_path = IDE.fs:join(dir, new_name)

        if IDE.fs:exists(new_path) then
            IDE.ui:warn('Already exists: ' .. new_name)
            return
        end

        local ok, err = IDE.fs:rename(node.path, new_path)
        if not ok then
            IDE.ui:error('Rename failed: ' .. (err or 'unknown error'))
            return
        end

        -- Update clipboard reference if renamed file was in clipboard
        if ft._clipboard and ft._clipboard.path == node.path then
            ft._clipboard.path = new_path
        end

        -- Notify LSP about the rename
        if IDE.lsp then
            IDE.lsp:notify_file_renamed(node.path, new_path)
        end

        IDE.ui:info(old_name .. ' -> ' .. new_name)
        ft:_build_tree()
        ft:_select_path(new_path)
    end, { default = old_name })
end

--- Copy the selected node's path to the system clipboard.
function FileTree:_yank_path()
    local node = self._tree[self._selected]
    if not node then return end

    IDE.ui:copy_to_clipboard(node.path)
    IDE.ui:info('Copied path: ' .. node.path)
end

--- Mark the selected node for copying.
function FileTree:_copy_to_clipboard()
    local node = self._tree[self._selected]
    if not node then return end

    self._clipboard = { path = node.path, op = 'copy' }
    local name = IDE and IDE.fs:basename(node.path) or vim.fs.basename(node.path)
    IDE.ui:info('Copied: ' .. name)
    self:_render() -- refresh footer to show clipboard state
end

--- Mark the selected node for moving (cut).
function FileTree:_cut_to_clipboard()
    local node = self._tree[self._selected]
    if not node then return end

    self._clipboard = { path = node.path, op = 'cut' }
    local name = IDE and IDE.fs:basename(node.path) or vim.fs.basename(node.path)
    IDE.ui:info('Cut: ' .. name)
    self:_render() -- refresh footer to show clipboard state
end

--- Paste the clipboard file/directory into the current context directory.
function FileTree:_paste()
    if not self._clipboard then
        IDE.ui:warn('Nothing in clipboard')
        return
    end

    local src = self._clipboard.path
    if not IDE.fs:exists(src) then
        IDE.ui:error('Source no longer exists: ' .. src)
        self._clipboard = nil
        self:_render()
        return
    end

    local dest_dir = self:_context_dir()
    local name = IDE and IDE.fs:basename(src) or vim.fs.basename(src)
    local dest = IDE.fs:join(dest_dir, name)

    -- Handle name conflict: add _copy suffix
    if IDE.fs:exists(dest) and dest ~= src then
        local base = name:match('^(.+)%.[^.]+$')
        local ext = name:match('%.([^.]+)$')
        if base and ext then
            dest = IDE.fs:join(dest_dir, base .. '_copy.' .. ext)
        else
            dest = IDE.fs:join(dest_dir, name .. '_copy')
        end
    end

    local ft = self
    local ok, err

    if self._clipboard.op == 'copy' then
        if IDE.fs:is_directory(src) then
            ok, err = ft:_copy_directory_recursive(src, dest)
        else
            ok, err = IDE.fs:copy(src, dest)
        end
        if not ok then
            IDE.ui:error('Copy failed: ' .. (err or 'unknown error'))
            return
        end
        IDE.ui:info('Pasted copy: ' .. (IDE.fs:basename(dest)))
    else
        -- Cut = move
        ok, err = IDE.fs:rename(src, dest)
        if not ok then
            IDE.ui:error('Move failed: ' .. (err or 'unknown error'))
            return
        end
        if IDE.lsp then
            IDE.lsp:notify_file_renamed(src, dest)
        end
        self._clipboard = nil
        IDE.ui:info('Moved: ' .. name)
    end

    ft._expanded[dest_dir] = true
    ft:_build_tree()
    ft:_select_path(dest)
end

--- Recursively copy a directory.
---@param src string
---@param dest string
---@return boolean, string|nil
function FileTree:_copy_directory_recursive(src, dest)
    IDE.fs:mkdir(dest)
    local entries = IDE.fs:list(src)
    for _, entry in ipairs(entries) do
        local s = IDE.fs:join(src, entry.name)
        local d = IDE.fs:join(dest, entry.name)
        if entry.type == 'directory' then
            local ok, err = self:_copy_directory_recursive(s, d)
            if not ok then return false, err end
        else
            local ok, err = IDE.fs:copy(s, d)
            if not ok then return false, err end
        end
    end
    return true, nil
end

function FileTree:close()
    if not self._mounted then return end
    self._mounted = false
    if self._shadow then self._shadow:close(); self._shadow = nil end
    if self._win and self._win:is_valid() then self._win:close(true) end
    if self._buf and self._buf:is_valid() then self._buf:close(true) end
    self._win = nil
    self._buf = nil
end

function FileTree:is_visible()
    return self._mounted and self._win ~= nil and self._win:is_valid()
end

function FileTree:toggle()
    if self:is_visible() then
        self:close()
    else
        self:show()
    end
end

function FileTree:__tostring()
    return string.format('FileTree(%s, %d nodes)', self._cwd, #self._tree)
end

return FileTree
