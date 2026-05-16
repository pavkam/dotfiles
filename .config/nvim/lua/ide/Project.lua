-- Project: workspace/project detection and metadata.
-- Detects project root, type, framework, and provides file search within the project.

local EventEmitter = require 'ide.EventEmitter'

local Project = Class('Project')
Class.include(Project, EventEmitter)

--- Well-known root markers for project detection.
Project.ROOT_MARKERS = {
    -- VCS
    '.git',

    -- JS/TS
    'package.json',

    -- Go
    'go.mod',
    'go.sum',

    -- Rust
    'Cargo.toml',

    -- Python
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    'poetry.lock',

    -- Build systems
    'Makefile',

    -- Lua / Neovim
    'lazy-lock.json',
    '.luarc.json',
    '.luarc.jsonc',
    '.luacheckrc',
    '.stylua.toml',
    'stylua.toml',
    'selene.toml',
    'selene.yml',

    -- .NET (glob patterns not supported by vim.fs.find, checked separately)
    -- '*.sln', '*.csproj' — handled in _detect_dotnet()
}

--- Map of root markers to project types.
Project.TYPE_MARKERS = {
    ['go.mod'] = 'go',
    ['Cargo.toml'] = 'rust',
    ['pyproject.toml'] = 'python',
    ['setup.py'] = 'python',
    ['setup.cfg'] = 'python',
    ['requirements.txt'] = 'python',
    ['poetry.lock'] = 'python',
    ['tsconfig.json'] = 'typescript',
    ['package.json'] = 'javascript',
    ['.luarc.json'] = 'lua',
    ['lazy-lock.json'] = 'lua',
}

---@param root string
function Project:init(root)
    assert(type(root) == 'string' and root ~= '', 'project root required')
    self._root = root
    self._pkg_cache = nil -- cached parsed package.json
end

---@return string
function Project:root()
    return self._root
end

---@return string
function Project:name()
    return vim.fs.basename(self._root)
end

--- Ordered type markers (more specific first, general last).
Project._TYPE_MARKER_ORDER = {
    { 'go.mod', 'go' },
    { 'Cargo.toml', 'rust' },
    { 'pyproject.toml', 'python' },
    { 'setup.py', 'python' },
    { 'setup.cfg', 'python' },
    { 'requirements.txt', 'python' },
    { 'poetry.lock', 'python' },
    { 'tsconfig.json', 'typescript' },
    { '.luarc.json', 'lua' },
    { 'lazy-lock.json', 'lua' },
    { 'package.json', 'javascript' },
}

--- Detect the project type from root markers, .NET files, and package.json parsing.
---@return string|nil
function Project:type()
    -- Check marker files first
    for _, entry in ipairs(Project._TYPE_MARKER_ORDER) do
        if self:has_file(entry[1]) then
            -- For package.json, refine: could be typescript if TS dep is present
            if entry[1] == 'package.json' then
                local node_type = self:_detect_node_type()
                return node_type or 'javascript'
            end
            return entry[2]
        end
    end

    -- Check .NET (glob patterns)
    if self:_detect_dotnet() then
        return 'dotnet'
    end

    return nil
end

--- Parse and cache the project's package.json.
---@return table|nil # parsed JSON data or nil
function Project:_read_package_json()
    if self._pkg_cache ~= nil then
        return self._pkg_cache ~= false and self._pkg_cache or nil
    end

    local pkg_path = vim.fs.joinpath(self._root, 'package.json')
    local stat = vim.uv.fs_stat(pkg_path)
    if not stat then
        self._pkg_cache = false
        return nil
    end

    local fd = vim.uv.fs_open(pkg_path, 'r', 438)
    if not fd then
        self._pkg_cache = false
        return nil
    end

    local data = vim.uv.fs_read(fd, stat.size, 0)
    vim.uv.fs_close(fd)
    if not data then
        self._pkg_cache = false
        return nil
    end

    local ok, parsed = pcall(vim.json.decode, data)
    if not ok or type(parsed) ~= 'table' then
        self._pkg_cache = false
        return nil
    end

    self._pkg_cache = parsed
    return parsed
end

--- Detect Node.js project subtype from package.json dependencies.
--- Returns a refined type: 'typescriptreact', 'typescript', 'javascriptreact', or 'javascript'.
---@return string|nil
function Project:_detect_node_type()
    local data = self:_read_package_json()
    if not data then return nil end

    local deps = data.dependencies or {}
    local dev = data.devDependencies or {}
    local has_ts = deps['typescript'] ~= nil or dev['typescript'] ~= nil
    local has_react = deps['react'] ~= nil or dev['react'] ~= nil

    if has_ts and has_react then return 'typescriptreact' end
    if has_ts then return 'typescript' end
    if has_react then return 'javascriptreact' end
    return 'javascript'
end

--- Detect the framework used in the project from package.json or config files.
--- Returns the detected framework name or nil.
---@return string|nil # e.g. 'react', 'next', 'vue', 'angular', 'svelte', 'express', 'django', 'flask', 'gin', 'fiber', 'actix', nil
function Project:framework()
    -- Node.js frameworks (from package.json)
    local data = self:_read_package_json()
    if data then
        local deps = vim.tbl_extend('force', data.dependencies or {}, data.devDependencies or {})
        -- Order matters: more specific frameworks first
        if deps['next'] then return 'next' end
        if deps['nuxt'] then return 'nuxt' end
        if deps['@angular/core'] then return 'angular' end
        if deps['svelte'] then return 'svelte' end
        if deps['vue'] then return 'vue' end
        if deps['react'] then return 'react' end
        if deps['express'] then return 'express' end
        if deps['fastify'] then return 'fastify' end
        if deps['koa'] then return 'koa' end
        if deps['hono'] then return 'hono' end
        return 'node'
    end

    -- Go frameworks (from go.mod imports)
    local go_mod = vim.fs.joinpath(self._root, 'go.mod')
    if vim.uv.fs_stat(go_mod) then
        local content = self:_read_file(go_mod)
        if content then
            if content:find('gin%-gonic/gin') then return 'gin' end
            if content:find('gofiber/fiber') then return 'fiber' end
            if content:find('labstack/echo') then return 'echo' end
            if content:find('go%-chi/chi') then return 'chi' end
        end
        return nil
    end

    -- Python frameworks (from pyproject.toml or requirements.txt)
    local pyproject = vim.fs.joinpath(self._root, 'pyproject.toml')
    if vim.uv.fs_stat(pyproject) then
        local content = self:_read_file(pyproject)
        if content then
            if content:find('django') or content:find('Django') then return 'django' end
            if content:find('flask') or content:find('Flask') then return 'flask' end
            if content:find('fastapi') or content:find('FastAPI') then return 'fastapi' end
        end
        return nil
    end

    local reqs = vim.fs.joinpath(self._root, 'requirements.txt')
    if vim.uv.fs_stat(reqs) then
        local content = self:_read_file(reqs)
        if content then
            if content:find('django') or content:find('Django') then return 'django' end
            if content:find('flask') or content:find('Flask') then return 'flask' end
            if content:find('fastapi') or content:find('FastAPI') then return 'fastapi' end
        end
        return nil
    end

    -- Rust frameworks (from Cargo.toml)
    local cargo = vim.fs.joinpath(self._root, 'Cargo.toml')
    if vim.uv.fs_stat(cargo) then
        local content = self:_read_file(cargo)
        if content then
            if content:find('actix') then return 'actix' end
            if content:find('axum') then return 'axum' end
            if content:find('rocket') then return 'rocket' end
        end
        return nil
    end

    return nil
end

--- Read a file's full contents (low-level helper, no IDE dependency).
---@param path string
---@return string|nil
function Project:_read_file(path)
    local fd = vim.uv.fs_open(path, 'r', 438)
    if not fd then return nil end
    local stat = vim.uv.fs_fstat(fd)
    if not stat or stat.size == 0 then vim.uv.fs_close(fd); return nil end
    local data = vim.uv.fs_read(fd, stat.size, 0)
    vim.uv.fs_close(fd)
    return data
end

--- Detect .NET projects by looking for *.sln or *.csproj files in the root.
---@return boolean
function Project:_detect_dotnet()
    local handle = vim.uv.fs_scandir(self._root)
    if not handle then return false end
    while true do
        local name, typ = vim.uv.fs_scandir_next(handle)
        if not name then break end
        if typ == 'file' then
            if name:match('%.sln$') or name:match('%.csproj$') then
                return true
            end
        end
    end
    return false
end

--- Parse the Go module name from go.mod.
---@return string|nil # the module path, e.g. "github.com/user/repo"
function Project:go_module()
    local go_mod = vim.fs.joinpath(self._root, 'go.mod')
    local content = self:_read_file(go_mod)
    if not content then return nil end
    return content:match('^module%s+(%S+)')
end

--- Check if a file exists relative to the project root.
---@param name string
---@return boolean
function Project:has_file(name)
    return vim.uv.fs_stat(vim.fs.joinpath(self._root, name)) ~= nil
end

--- Find a file by walking up from a start path within the project.
---@param name string|string[]
---@param start_path string|nil
---@return string|nil
function Project:find_file(name, start_path)
    local results = vim.fs.find(
        type(name) == 'string' and { name } or name,
        {
            path = start_path or self._root,
            upward = true,
            stop = self._root,
            limit = 1,
        }
    )
    return results[1]
end

--- Get a path relative to the project root.
---@param path string # absolute path
---@return string # path relative to root, or the original path if outside root
function Project:relative_path(path)
    if not path then return '' end
    local root = vim.fs.normalize(self._root)
    path = vim.fs.normalize(path)
    if path:sub(1, #root) == root then
        return path:sub(#root + 2)
    end
    return path
end

--- Get path components: workspace path, project name, and display path.
---@return { workspace_path: string, project_name: string, project_root: string }
function Project:path_components()
    local root = vim.fs.normalize(self._root)
    return {
        workspace_path = vim.fs.dirname(root),
        project_name = vim.fs.basename(root),
        project_root = root,
    }
end

--- Format a file path relative to this project for display.
---@param path string # absolute file path
---@return string # formatted relative path
function Project:format_relative(path)
    return self:relative_path(path)
end

--- Get the .nvim settings directory for this project.
---@return string
function Project:settings_dir()
    return vim.fs.joinpath(self._root, '.nvim')
end

--- Whether this project is under git.
---@return boolean
function Project:is_git()
    return self:has_file('.git')
end

--- Find the DAP launch.json for this project.
---@return string|nil
function Project:launch_json()
    local nvim_dap = vim.fs.joinpath(self:settings_dir(), 'dap.json')
    if vim.fn.filereadable(nvim_dap) == 1 then return nvim_dap end
    local vscode = vim.fs.joinpath(self._root, '.vscode', 'launch.json')
    if vim.fn.filereadable(vscode) == 1 then return vscode end
    return nil
end

--- Find a JS/TS binary in node_modules/.bin.
---@param bin string
---@return string|nil
function Project:js_bin(bin)
    local path = vim.fs.joinpath(self._root, 'node_modules', '.bin', bin)
    if vim.fn.executable(path) == 1 then return path end
    return nil
end

--- Check if a JS dependency exists in package.json.
---@param dep string
---@return boolean
function Project:js_has_dependency(dep)
    local data = self:_read_package_json()
    if not data then return false end
    local deps = data.dependencies or {}
    local dev = data.devDependencies or {}
    return deps[dep] ~= nil or dev[dep] ~= nil
end

--- Find eslint config file in the project.
---@return string|nil
function Project:eslint_config()
    for _, name in ipairs({ '.eslintrc.js', '.eslintrc.cjs', '.eslintrc.json', '.eslintrc.yml', 'eslint.config.js', 'eslint.config.mjs', 'eslint.config.cjs' }) do
        local path = self:find_file(name)
        if path then return path end
    end
    return nil
end

--- Find golangci-lint config file in the project.
---@return string|nil
function Project:golangci_config()
    for _, name in ipairs({ '.golangci.yml', '.golangci.yaml', '.golangci.toml', '.golangci.json' }) do
        if self:has_file(name) then
            return vim.fs.joinpath(self._root, name)
        end
    end
    return nil
end

---@return string
function Project:__tostring()
    local fw = self:framework()
    local type_str = self:type() or '?'
    if fw then type_str = type_str .. '/' .. fw end
    return string.format('Project(%s, %s)', self:name(), type_str)
end

-- Class methods

--- Detect the project for a given file path or the current buffer.
---@param path string|nil
---@return Project|nil
function Project.detect(path)
    if not path then
        path = vim.api.nvim_buf_get_name(0)
        if path == '' then return nil end
    end

    local dir = vim.fs.dirname(path)
    local found = vim.fs.find(Project.ROOT_MARKERS, {
        path = dir,
        upward = true,
        stop = vim.uv.os_homedir(),
        limit = 1,
    })

    if found[1] then
        return Project(vim.fs.dirname(found[1]))
    end

    -- Check for .NET projects (glob patterns not supported by vim.fs.find)
    local check_dir = dir
    local home = vim.uv.os_homedir()
    while check_dir and check_dir ~= home and #check_dir > 1 do
        local handle = vim.uv.fs_scandir(check_dir)
        if handle then
            while true do
                local name, typ = vim.uv.fs_scandir_next(handle)
                if not name then break end
                if typ == 'file' and (name:match('%.sln$') or name:match('%.csproj$')) then
                    return Project(check_dir)
                end
            end
        end
        check_dir = vim.fs.dirname(check_dir)
    end

    return nil
end

--- Create a project from the current working directory.
---@return Project
function Project.from_cwd()
    return Project(assert(vim.uv.cwd()))
end

return Project
