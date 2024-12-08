-- Filesystem API
---@class fs
local M = {}

--- Expands a path to its canonical form resolving symlinks and removing extra slashes.
---@param path string # the path to check.
---@return string|nil # the expanded path or nil if the path could not be expanded.
function M.expand_path(path)
    xassert {
        path = { path, { 'string', ['>'] = 0 } },
    }

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

---@alias fs.object_type # The type of a file system object.
---| "file" # a regular file.
---| "directory" # a directory.
---| "link" # a symbolic link.
---| "fifo" # a named pipe.
---| "socket" # a socket.
---| "char" # a character device.
---| "block" # a block device.

--- Gets the type of file identified by path.
---@param path string # the path to check.
---@return fs.object_type|nil # the type of the file system object or `nil`.
---if the file does not exist
function M.path_type(path)
    local res_path = M.expand_path(path)
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

--- Splits a file path into its components
---@param path string # the path to split
---@return string, string, string, string # the components of the path
function M.split_path(path)
    local expanded_path = M.expand_path(path)
    if not path then
        return path, '', '', ''
    end

    ---@cast expanded_path string

    local dir_name = vim.fn.fnamemodify(expanded_path, ':h')
    local base_name = vim.fn.fnamemodify(expanded_path, ':t')
    local extension = vim.fn.fnamemodify(expanded_path, ':e')
    local compound_extension = extension

    local parts = vim.split(base_name, '%.')
    if #parts > 2 then
        compound_extension = table.concat(vim.list_slice(parts, #parts - 1), '.')
    end

    return dir_name, base_name, extension, compound_extension
end

--- Gets the base name of a path.
---@param path string # the path to check.
---@return string # the base name of the path.
function M.base_name(path)
    local expanded_path = M.expand_path(path)
    if not path then
        return path
    end

    return vim.fs.basename(expanded_path) --[[@as string]]
end

--- Gets the directory name of a path.
---@param path string # the path to check.
---@return string # the directory name of the path.
function M.directory_name(path)
    local expanded_path = M.expand_path(path)
    if not path then
        return path
    end

    return vim.fs.dirname(expanded_path) --[[@as string]]
end

--- The data directory of NeoVim
M.DATA_DIRECTORY = M.expand_path(vim.fn.stdpath 'data' --[[@as string]]) --[[@as string]]

--- The config directory of NeoVim
M.CONFIGURATION_DIRECTORY = M.expand_path(vim.fn.stdpath 'config' --[[@as string]]) --[[@as string]]

--- The cache directory of NeoVim
M.CACHE_DIRECTORY = M.expand_path(vim.fn.stdpath 'cache' --[[@as string]]) --[[@as string]]

xassert {
    DATA_DIRECTORY = { M.DATA_DIRECTORY, 'string' },
    CONFIGURATION_DIRECTORY = { M.CONFIGURATION_DIRECTORY, 'string' },
    CACHE_DIRECTORY = { M.CACHE_DIRECTORY, 'string' },
}

-- Joins a list of paths into a single path.
---@param ... string # the list of paths to join.
function M.join_paths(...)
    xassert {
        paths = { { ... }, { 'list', ['*'] = { 'string', ['>'] = 0 } } },
    }

    return vim.fs.joinpath(...)
end

--- Scans for files in a list of directories and returns the first found one.
---@param base_paths string|(string|nil)[] # the list of base paths to check.
---@param files string|(string|nil)[] # the list of files to check.
---@return string|nil # the first found file or nil if none found.
function M.scan(base_paths, files)
    xassert {
        base_paths = {
            base_paths,
            { 'string', { 'list', ['*'] = { 'nil', { 'string', ['>'] = 0 } } } },
        },
        files = {
            files,
            { 'string', { 'list', ['*'] = { 'nil', { 'string', ['>'] = 0 } } } },
        },
    }

    base_paths = table.to_list(base_paths) --[[@as string[] ]]
    files = table.to_list(files) --[[@as string[] ]]

    for _, path in ipairs(base_paths) do
        for _, file in ipairs(files) do
            local full = M.join_paths(path, file)
            if full and M.file_exists(full) then
                return M.join_paths(path, file)
            end
        end
    end

    return nil
end

---@class (exact) fs.write_text_file_opts # The options for writing a text file.
---@field throw_errors boolean|nil # whether to throw errors or no (default: `false`).

--- Writes a string to a file
---@param path string # the path to the file to write to.
---@param content string # the content to write.
---@param opts fs.write_text_file_opts|nil # the options to use when writing the file.
---@return boolean, string|nil # true if the write was successful, false otherwise.
function M.write_text_file(path, content, opts)
    opts = table.merge(opts, {
        throw_errors = false,
    })

    xassert {
        path = { path, { 'string', ['>'] = 0 } },
        content = { content, 'string' },
        opts = {
            opts,
            {
                throw_errors = 'boolean',
            },
        },
    }

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

---@class (exact) fs.format_relative_path_opts # The options for formatting a relative path.
---@field ellipsis string|nil # the ellipsis to use, defaults to '…'.
---@field include_base_dir boolean|nil # whether to include the base directory in the path, defaults to false.
---@field max_width number|nil # the maximum width of the path, defaults to unlimited.

--- Simplifies a path by making it relative to another path and adding ellipsis.
---@param prefix string # the prefix to make the path relative to.
---@param path string # the path to simplify.
---@param opts fs.format_relative_path_opts|nil # the options to use when simplifying the path.
---@return string # the simplified path.
function M.format_relative_path(prefix, path, opts)
    opts = table.merge(opts, {
        ellipsis = require('icons').TUI.Ellipsis,
        include_base_dir = false,
    })

    xassert {
        prefix = { prefix, 'string' },
        path = { path, { 'string', ['>'] = 0 } },
        opts = {
            opts,
            {
                'nil',
                {
                    ellipsis = 'string',
                    include_base_dir = 'boolean',
                    max_width = { 'nil', 'integer' },
                },
            },
        },
    }

    for _, p in ipairs { prefix, vim.env.HOME } do
        p = M.expand_path(p) --[[@as string]]

        if string.starts_with(path, p) then
            path = string.sub(path, #p + 1)

            if opts.include_base_dir then
                path = M.join_paths(M.base_name(M.directory_name(p)), path)
            end

            if #opts.ellipsis > 0 then
                path = M.join_paths(opts.ellipsis, path)
            end

            -- TODO: use abbreviate
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
