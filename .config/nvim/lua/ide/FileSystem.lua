-- File system abstraction.
-- Wraps vim.uv.fs_*, vim.fs.*, and vim.fn.* into a clean OOP interface.

local FileSystem = Class('FileSystem')

function FileSystem:init() end

--- Expand a path to its canonical form, resolving symlinks.
---@param path string
---@return string|nil
function FileSystem:expand(path)
    local ok, expanded = pcall(vim.fn.expand, path)
    if not ok then return nil end
    ok, expanded = pcall(vim.fs.normalize, expanded)
    if not ok then return nil end
    local real, err = vim.uv.fs_realpath(expanded)
    return (not err and real) and real or nil
end

--- Check if a path is a file.
---@param path string
---@return boolean
function FileSystem:is_file(path)
    local stat = vim.uv.fs_stat(path)
    return stat ~= nil and stat.type == 'file'
end

--- Check if a path is a directory.
---@param path string
---@return boolean
function FileSystem:is_directory(path)
    if not path then return false end
    local stat = vim.uv.fs_stat(path)
    return stat ~= nil and stat.type == 'directory'
end

--- Check if a path exists (file or directory).
---@param path string
---@return boolean
function FileSystem:exists(path)
    if not path then return false end
    return vim.uv.fs_stat(path) ~= nil
end

--- Join path components.
---@param ... string
---@return string
function FileSystem:join(...)
    return vim.fs.joinpath(...)
end

--- Get the basename of a path.
---@param path string
---@return string
function FileSystem:basename(path)
    return vim.fs.basename(path)
end

--- Get the directory name of a path.
---@param path string
---@return string
function FileSystem:dirname(path)
    return vim.fs.dirname(path)
end

--- Get the current working directory.
---@return string
function FileSystem:cwd()
    return assert(vim.uv.cwd())
end

--- Get the home directory.
---@return string
function FileSystem:home()
    return assert(vim.uv.os_homedir())
end

--- Neovim's standard data directory.
---@return string
function FileSystem:data_dir()
    return vim.fn.stdpath('data') --[[@as string]]
end

--- Neovim's standard cache directory.
---@return string
function FileSystem:cache_dir()
    return vim.fn.stdpath('cache') --[[@as string]]
end

--- Neovim's standard config directory.
---@return string
function FileSystem:config_dir()
    return vim.fn.stdpath('config') --[[@as string]]
end

--- Check if an executable exists in PATH.
---@param name string
---@return boolean
function FileSystem:executable(name)
    return vim.fn.executable(name) == 1
end

--- Make a directory (with parents).
---@param path string
function FileSystem:mkdir(path)
    vim.fn.mkdir(path, 'p')
end

--- Read a file's contents.
---@param path string
---@return string|nil, string|nil # contents or nil, error message or nil
function FileSystem:read(path)
    if not path then return nil, 'path is nil' end
    local fd, err = vim.uv.fs_open(path, 'r', 438)
    if not fd then return nil, err end
    local stat, stat_err = vim.uv.fs_fstat(fd)
    if not stat then vim.uv.fs_close(fd); return nil, stat_err end
    if stat.size == 0 then vim.uv.fs_close(fd); return '', nil end
    local data, read_err = vim.uv.fs_read(fd, stat.size, 0)
    vim.uv.fs_close(fd)
    if not data then return nil, read_err end
    return data, nil
end

--- Write content to a file.
---@param path string
---@param content string
---@return boolean, string|nil # success, error message
function FileSystem:write(path, content)
    if not path then return false, 'path is nil' end
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    local fd, err = vim.uv.fs_open(path, 'w', 438)
    if not fd then return false, err end
    vim.uv.fs_write(fd, content)
    vim.uv.fs_close(fd)
    return true, nil
end

--- Rename (move) a file.
---@param old_path string
---@param new_path string
---@return boolean, string|nil # success, error message
function FileSystem:rename(old_path, new_path)
    local ok, err = vim.uv.fs_rename(old_path, new_path)
    return ok ~= nil, err
end

--- Delete a file.
---@param path string
---@return boolean, string|nil # success, error message
function FileSystem:delete(path)
    local ok, err = vim.uv.fs_unlink(path)
    return ok ~= nil, err
end

--- Format a path relative to a base directory.
---@param base string
---@param path string
---@param opts? { include_base_dir?: boolean }
---@return string
function FileSystem:relative_path(base, path, opts)
    opts = opts or {}
    if not base or not path then return path or '' end
    base = vim.fs.normalize(base)
    path = vim.fs.normalize(path)
    if path:sub(1, #base) == base then
        local rel = path:sub(#base + 2)
        if opts.include_base_dir then
            return vim.fs.basename(base) .. '/' .. rel
        end
        return rel
    end
    return path
end

--- Scan directories for a file. Returns first match.
---@param dirs string|string[] # directories to search
---@param names string|string[] # file names to look for
---@return string|nil # full path of first found file
function FileSystem:scan(dirs, names)
    dirs = type(dirs) == 'string' and { dirs } or dirs
    names = type(names) == 'string' and { names } or names
    for _, dir in ipairs(dirs) do
        for _, name in ipairs(names) do
            local path = vim.fs.joinpath(dir, name)
            if vim.uv.fs_stat(path) then return path end
        end
    end
    return nil
end

--- Find files by walking up from a start path.
---@param names string|string[] # file names to find
---@param opts { path?: string, stop?: string, limit?: integer }|nil
---@return string[] # list of found file paths
function FileSystem:find(names, opts)
    opts = opts or {}
    return vim.fs.find(
        type(names) == 'string' and { names } or names,
        {
            path = opts.path or self:cwd(),
            upward = true,
            stop = opts.stop or self:home(),
            limit = opts.limit or 1,
        }
    )
end

--- List entries in a directory.
---@param dir string
---@return { name: string, type: string }[] # type is 'file', 'directory', or 'link'
function FileSystem:list(dir)
    local entries = {}
    local handle = vim.uv.fs_opendir(dir, nil, 100)
    if not handle then return entries end
    while true do
        local batch = vim.uv.fs_readdir(handle)
        if not batch then break end
        for _, entry in ipairs(batch) do
            entries[#entries + 1] = { name = entry.name, type = entry.type }
        end
    end
    vim.uv.fs_closedir(handle)
    table.sort(entries, function(a, b)
        if a.type ~= b.type then return a.type == 'directory' end
        return a.name < b.name
    end)
    return entries
end

--- Get file/directory metadata.
---@param path string
---@return { type: string, size: integer, mtime: integer }|nil
function FileSystem:stat(path)
    local s = vim.uv.fs_stat(path)
    if not s then return nil end
    return { type = s.type, size = s.size, mtime = s.mtime.sec }
end

--- Recursively walk a directory tree.
---@param dir string
---@param callback fun(path: string, type: string) # called for each entry
---@param opts { max_depth?: integer, filter?: fun(name: string, type: string): boolean }|nil
function FileSystem:walk(dir, callback, opts)
    opts = opts or {}
    local visited = {}
    local function recurse(d, depth)
        if opts.max_depth and depth >= opts.max_depth then return end
        local real = vim.uv.fs_realpath(d)
        if real then
            if visited[real] then return end
            visited[real] = true
        end
        local entries = self:list(d)
        for _, e in ipairs(entries) do
            local full = vim.fs.joinpath(d, e.name)
            if not opts.filter or opts.filter(e.name, e.type) then
                callback(full, e.type)
            end
            if e.type == 'directory' then
                recurse(full, depth + 1)
            end
        end
    end
    recurse(dir, 0)
end

--- Watch a directory for changes.
---@param path string
---@param callback fun(filename: string, events: table)
---@return fun() # call to stop watching
function FileSystem:watch(path, callback)
    local handle = vim.uv.new_fs_event()
    if not handle then return function() end end
    handle:start(path, { recursive = false }, vim.schedule_wrap(function(err, filename, events)
        if not err and filename then
            callback(filename, events)
        end
    end))
    return function()
        if handle and not handle:is_closing() then
            handle:stop()
            handle:close()
        end
    end
end

--- Copy a file.
---@param src string
---@param dst string
---@return boolean, string|nil # success, error
function FileSystem:copy(src, dst)
    local ok, err = vim.uv.fs_copyfile(src, dst)
    return ok ~= nil, err
end

--- Recursively delete a directory and its contents.
---@param path string
---@return boolean, string|nil # success, error
function FileSystem:delete_recursive(path)
    local s = vim.uv.fs_stat(path)
    if not s then return false, 'path does not exist' end
    if s.type == 'file' or s.type == 'link' then
        return self:delete(path)
    end
    -- Delete contents first
    for _, entry in ipairs(self:list(path)) do
        local full = vim.fs.joinpath(path, entry.name)
        if entry.type == 'directory' then
            local ok, err = self:delete_recursive(full)
            if not ok then return false, err end
        else
            local ok, err = self:delete(full)
            if not ok then return false, err end
        end
    end
    -- Delete the directory itself
    local ok, err = vim.uv.fs_rmdir(path)
    return ok ~= nil, err
end

--- Check if a path is a symbolic link.
---@param path string
---@return boolean
function FileSystem:is_link(path)
    local s = vim.uv.fs_lstat(path)
    return s ~= nil and s.type == 'link'
end

--- Get the file extension.
---@param path string
---@return string # extension without dot, or empty string
function FileSystem:extension(path)
    return path:match('%.([^%.]+)$') or ''
end

--- Format a path for display: relative to cwd with ~ for home.
---@param path string
---@param opts? { max_len?: integer }
---@return string
function FileSystem:display_path(path, opts)
    opts = opts or {}
    local result = vim.fn.fnamemodify(path, ':~:.')
    if opts.max_len and #result > opts.max_len then
        result = '…' .. result:sub(-(opts.max_len - 1))
    end
    return result
end

--- Shorten a path using first letters of intermediate directories.
---@param path string
---@return string
function FileSystem:shorten(path)
    return vim.fn.pathshorten(path)
end

---@return string
function FileSystem:__tostring()
    return string.format('FileSystem(cwd=%s)', self:cwd())
end

return FileSystem
