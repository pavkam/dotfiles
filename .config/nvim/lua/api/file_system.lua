-- Filesystem API
---@class api.file_system
local M = {}

--- TODO: cleanup asserts
--- Expands a path to its canonical form resolving symlinks and removing extra slashes
---@param path string # the path to check
---@return string|nil # the expanded path or nil if the path could not be expanded
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

--- The data directory of NeoVim
M.DATA_DIRECTORY = M.expand_path(vim.fn.stdpath 'data' --[[@as string]])

--- The config directory of NeoVim
M.CONFIGURATION_DIRECTORY = M.expand_path(vim.fn.stdpath 'config' --[[@as string]])

--- The cache directory of NeoVim
M.CACHE_DIRECTORY = M.expand_path(vim.fn.stdpath 'cache' --[[@as string]])

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
