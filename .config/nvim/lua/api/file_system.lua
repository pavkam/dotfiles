-- Filesystem API
---@class api.file_system
local M = {}

--- TODO: cleanup asserts
--- Expands a path to its canonical form resolving symlinks and removing extra slashes.
---@param path string # the path to check.
---@return string|nil # the expanded path or nil if the path could not be expanded.
function M.expand_path(path)
    assert(type(path) == 'string' and path ~= '')

    local ok, expanded = pcall(vim.fn.expand, path)
    if not ok then
        return nil
    end
    ok, expanded = pcall(vim.fs.normalize, expanded)
    if not ok then
        return nil
    end

    local real_path, err = vim.uv.fs_realpath(expanded)

    if not err and real_path then
        return real_path
    end

    return nil
end

---@alias api.file_system.ObjectType # The type of a file system object.
---| "file" # a regular file.
---| "directory" # a directory.
---| "link" # a symbolic link.
---| "fifo" # a named pipe.
---| "socket" # a socket.
---| "char" # a character device.
---| "block" # a block device.

--- Gets the type of file identified by path.
---@param path string # the path to check.
---@return api.file_system.ObjectType | nil # the type of the file system object or `nil`.
---if the file does not exist
function M.path_type(path)
    local res_path = ide.file_system.expand_path(path)
    if not res_path then
        return nil
    end

    local stat, err = vim.uv.fs_stat(res_path)
    if err or not stat then
        return nil
    end

    return stat.type
end

--- Checks if a directory exists.
---@param path string # the path to check.
---@return boolean # true if the file exists, false otherwise.
function M.directory_exists(path)
    return M.path_type(path) == 'directory'
end

--- Checks if a file exists.
---@param path string # the path to check.
---@return boolean # true if the file exists, false otherwise.
function M.file_exists(path)
    return M.path_type(path) == 'file'
end

---@class (exact) vim.PathComponents # The components of a path
---@field dir_name string # the directory name
---@field base_name string # the base name
---@field extension string # the extension
---@field compound_extension string # the compound extension

--- Splits a file path into its components
---@param path string # the path to split
---@return vim.PathComponents # the components of the path
function M.split_path(path)
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

--- The data directory of NeoVim
M.DATA_DIRECTORY = M.expand_path(vim.fn.stdpath 'data' --[[@as string]])

--- The config directory of NeoVim
M.CONFIGURATION_DIRECTORY = M.expand_path(vim.fn.stdpath 'config' --[[@as string]])

--- The cache directory of NeoVim
M.CACHE_DIRECTORY = M.expand_path(vim.fn.stdpath 'cache' --[[@as string]])

--- Scans for files in a list of directories and returns the first found one.
---@param base_paths string|(string|nil)[] # the list of base paths to check.
---@param files string|(string|nil)[] # the list of files to check.
---@return string|nil # the first found file or nil if none found.
function M.scan(base_paths, files)
    assert(type(base_paths) == 'string' or vim.islist(base_paths))
    assert(type(files) == 'string' or vim.islist(files))

    base_paths = table.to_list(base_paths)
    files = table.to_list(files)

    for _, path in ipairs(base_paths) do
        for _, file in ipairs(files) do
            local full = vim.fs.joinpath(path, file)
            if full and ide.file_system.file_exists(full) then
                return vim.fs.joinpath(path, file)
            end
        end
    end

    return nil
end

---@class vim.WriteTextFileOpts
---@field throw_errors boolean|nil # whether to throw errors or not, defaults to false

--- Writes a string to a file
---@param path string # the path to the file to write to.
---@param content string # the content to write.
---@param opts vim.WriteTextFileOpts|nil # the options to use when writing the file.
---@return boolean, string|nil # true if the write was successful, false otherwise.
function M.write_text_file(path, content, opts)
    opts = opts or {}
    opts.throw_errors = opts.throw_errors or false

    assert(type(path) == 'string' and path ~= '')
    assert(type(content) == 'string')
    assert(type(opts.throw_errors) == 'boolean')

    local file, err = io.open(path, 'w')
    if not file then
        if opts.throw_errors then
            error(err)
        end

        return false, err
    end

    local ok
    ok, err = file:write(content)
    if not ok then
        if opts.throw_errors then
            error(err)
        end

        return false, err
    end

    ok, err = file:close()
    if not ok then
        if opts.throw_errors then
            error(err)
        end

        return false, err
    end

    return true, nil
end
---@class (exact) api.fs.FormatRelativePathOpts # The options for formatting a relative path.
---@field ellipsis string|nil # the ellipsis to use, defaults to '…'.
---@field include_base_dir boolean|nil # whether to include the base directory in the path, defaults to false.
---@field max_width number|nil # the maximum width of the path, defaults to unlimited.

--- Simplifies a path by making it relative to another path and adding ellipsis.
---@param prefix string # the prefix to make the path relative to.
---@param path string # the path to simplify.
---@param opts api.fs.FormatRelativePathOpts|nil # the options to use when simplifying the path.
---@return string # the simplified path.
function M.format_relative_path(prefix, path, opts)
    opts = opts or {}
    opts.ellipsis = opts.ellipsis or require('icons').TUI.Ellipsis
    opts.include_base_dir = opts.include_base_dir or false

    assert(type(prefix) == 'string')
    assert(type(path) == 'string')
    assert(type(opts.ellipsis) == 'string')
    assert(type(opts.include_base_dir) == 'boolean')
    assert(type(opts.max_width) == 'number' or opts.max_width == nil)

    for _, p in ipairs { prefix, vim.env.HOME } do
        p = vim.fs.joinpath(p, '')

        if vim.startswith(path, p) then
            path = vim.fn.strcharpart(path, vim.fn.strlen(p))

            if opts.include_base_dir then
                path = vim.fs.joinpath(vim.fs.basename(vim.fs.dirname(p)), path)
            end

            if vim.fn.strwidth(opts.ellipsis) > 0 then
                path = vim.fs.joinpath(opts.ellipsis, path)
            end

            if opts.max_width ~= nil then
                local delta = vim.fn.strwidth(path) - opts.max_width

                if delta > 0 then
                    path = opts.ellipsis
                        .. vim.fn.strcharpart(path, 0, vim.fn.strlen(path) - delta - vim.fn.strwidth(opts.ellipsis))
                end
            end

            return path
        end
    end

    return path
end

return table.freeze(M)
