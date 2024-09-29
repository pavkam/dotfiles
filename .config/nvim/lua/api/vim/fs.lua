--- Joins two paths
---@param part1 string # the first part of the path
---@param part2 string # the second part of the path
---@return string # the joined path
local function join_paths(part1, part2)
    part1 = part1:gsub('([^/])$', '%1/'):gsub('//', '/')
    part2 = part2:gsub('^/', '')

    return part1 .. part2
end

--- Joins multiple paths
---@vararg string|nil # the paths to join
---@return string|nil # the joined path or nil if none of the paths are valid
function vim.fs.join_paths(...)
    ---@type string|nil
    local acc
    for _, part in ipairs { ... } do
        if part ~= nil then
            if acc then
                acc = join_paths(acc, part)
            else
                acc = part
            end
        end
    end

    return acc
end

--- Expands a path to its canonical form
---@param path string # the path to check
---@return string|nil # the expanded path or nil if the path could not be expanded
function vim.fs.expand_path(path)
    assert(type(path) == 'string' and path ~= '')

    local real_path, err = vim.uv.fs_realpath(vim.fn.expand(path))

    if not err and real_path then
        return real_path
    end
end

---@alias vim.FsObjType "file" | "directory" | "link" | "fifo" | "socket" | "char" | "block"

--- Gets the type of file identified by path
---@param path string # the path to check
---@return vim.FsObjType | nil # the type of the file system object or nil
---if the file does not exist
function vim.fs.path_type(path)
    local stat, err = vim.uv.fs_stat(vim.fn.expand(path))

    return not err and stat and stat.type or nil
end

--- Checks if a directory exists
---@param path string # the path to check
---@return boolean # true if the file exists, false otherwise
function vim.fs.dir_exists(path)
    return vim.fs.path_type(path) == 'directory'
end

--- Checks if a file exists
---@param path string # the path to check
---@return boolean # true if the file exists, false otherwise
function vim.fs.file_exists(path)
    return vim.fs.path_type(path) == 'file'
end

--- The data directory of NeoVim
vim.fs.data_dir = vim.fs.expand_path(vim.fn.stdpath 'data' --[[@as string]])

--- The config directory of NeoVim
vim.fs.config_dir = vim.fs.expand_path(vim.fn.stdpath 'config' --[[@as string]])

--- The cache directory of NeoVim
vim.fs.cache_dir = vim.fs.expand_path(vim.fn.stdpath 'cache' --[[@as string]])

--- Checks if files exist in a given directory and returns the first one that exists
---@param base_paths string|table<number, string|nil> # the list of base paths to check
---@param files string|table<number, string|nil> # the list of files to check
---@return string|nil # the first found file or nil if none exists
function vim.fs.first_found_file(base_paths, files)
    base_paths = vim.to_list(base_paths)
    files = vim.to_list(files)

    for _, path in ipairs(base_paths) do
        for _, file in ipairs(files) do
            local full = vim.fs.join_paths(path, file)
            if full and vim.fs.file_exists(full) then
                return vim.fs.join_paths(path, file)
            end
        end
    end

    return nil
end

---@type table<string, string>
local file_to_file_type = {}

--- Gets the file type of a file
---@param path string # the path to the file to get the type for
---@return string|nil # the file type or nil if the file type could not be determined
function vim.fs.file_type(path)
    assert(type(path) == 'string' and path ~= '')

    ---@type string|nil
    local file_type = file_to_file_type[path]
    if file_type then
        return file_type
    end

    file_type = vim.filetype.match { filename = path }
    if not file_type then
        for _, buf in ipairs(vim.fn.getbufinfo()) do
            if vim.fn.fnamemodify(buf.name, ':p') == path then
                return vim.filetype.match { buf = buf.bufnr }
            end
        end

        local bufn = vim.fn.bufadd(path)
        vim.fn.bufload(bufn)

        file_type = vim.filetype.match { buf = bufn }

        vim.api.nvim_buf_delete(bufn, { force = true })
    end

    file_to_file_type[path] = file_type

    return file_type
end

--- Simplifies a path by making it relative to another path and adding ellipsis
---@param prefix string # the prefix to make the path relative to
---@param path string # the path to simplify
---@return string # the simplified path
function vim.fs.format_relative_path(prefix, path)
    assert(type(prefix) == 'string')
    assert(type(path) == 'string')

    for _, p in ipairs { prefix, vim.env.HOME } do
        p = p:sub(-1) == '/' and p or p .. '/'

        if path:find(p, 1, true) == 1 then
            return '…/' .. path:sub(#p + 1)
        end
    end

    return path
end

---@class (exact) vim.PathComponents # The components of a path
---@field dir_name string # the directory name
---@field base_name string # the base name
---@field extension string # the extension
---@field compound_extension string # the compound extension

--- Splits a file path into its components
---@param path string # the path to split
---@return vim.PathComponents # the components of the path
function vim.fs.split_path(path)
    assert(type(path) == 'string' and path ~= '')

    local dir_name = vim.fn.fnamemodify(path, ':h')
    local base_name = vim.fn.fnamemodify(path, ':t')
    local extension = vim.fn.fnamemodify(path, ':e')
    local compound_extension = extension

    local parts = vim.split(base_name, '%.')
    if #parts > 2 then
        compound_extension = table.concat(vim.list_slice(parts, #parts - 1), '.')
    end

    return {
        dir_name = dir_name,
        base_name = base_name,
        extension = extension,
        compound_extension = compound_extension,
    }
end

--- Writes a string to a file
---@param path string # the path to the file to write to.
---@param content string # the content to write.
---@return boolean, string|nil # true if the write was successful, false otherwise.
function vim.fs.write_text_file(path, content)
    assert(type(path) == 'string' and path ~= '')

    local file, err = io.open(path, 'w')
    if not file then
        return false, err
    end

    local ok
    ok, err = file:write(content)
    if not ok then
        return false, err
    end

    ok, err = file:close()
    if not ok then
        return false, err
    end

    return true, nil
end
