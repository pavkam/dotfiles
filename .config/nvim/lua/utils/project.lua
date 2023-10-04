local files = require 'utils.files'

local launch_json_name = '/.vscode/launch.json'
local package_json_name = "package.json"
local node_modules_name = "node_modules"
local go_project_roots = { 'go.mod', 'go.sum' }

local M = {}

local function cwd(path)
    return path or vim.fn.getcwd()
end

local function parsed_package_json_has_dependency(parsed_json, type, dependency)
    if parsed_json[type] then
        for key, _ in pairs(parsed_json[type]) do
            if key == dependency then
                return true
            end
        end
    end

    return false
end

local function read_node_package_json(path)
    local root = files.find_root(cwd(path), package_json_name)

    if not root then
        return nil
    end

    local full_name = root .. "/" .. package_json_name
    local success, json_content = pcall(files.read_file, full_name)
    if not success or not json_content then
        return nil
    end

    return vim.json.decode(json_content)
end

local function get_nearest_node_modules_relative_path(path, sub_path)
    local root = files.find_root(cwd(path), package_json_name)

    if not root then
        return nil
    end

    local full_path = root .. "/" .. node_modules_name .. "/" .. sub_path
    if files.file_exists(full_path) then
        return full_path
    end

    return nil
end

function M.node_package_json_has_dependency(path, dependency)
    local parsed_json = read_node_package_json(path)
    if not parsed_json then
        return false
    end

    return (
        parsed_package_json_has_dependency(parsed_json, 'dependencies', dependency) or
        parsed_package_json_has_dependency(parsed_json, 'devDependencies', dependency)
    )
end

function M.get_node_package_jest_binary_path(path)
    if not M.node_package_json_has_dependency(path, 'jest') then
        return nil
    end

    return get_nearest_node_modules_relative_path(path, 'jest/bin/jest.js')
end

function M.go_project_has_golangci_config(path)
    if not M.get_project_language(path) == 'go' then
        return false
    end

    local root = files.find_root(cwd(path), vim.tbl_flatten { go_project_roots })
    if root then
        for _, ext in ipairs { 'yml', 'yaml', 'toml', 'json' } do
            if files.file_exists(root .. "/" .. ".golangci." .. ext) then
                return true
            end
        end
    end

    return false
end

function M.node_project_has_eslint_config(path)
    local root = files.find_root(cwd(path), package_json_name)

    if root then
        for _, name in ipairs { '.eslintrc.json', '.eslintrc.js', 'eslint.config.js', 'eslint.config.json' } do
            if files.file_exists(root .. "/" .. name) then
                return true
            end
        end
    end

    return false
end

function M.get_project_language(path)
    -- try javascript
    local parsed_package_json = read_node_package_json(path)
    if parsed_package_json then
        if parsed_package_json_has_dependency(parsed_package_json, 'dependencies', 'typescript') then
            if parsed_package_json_has_dependency(parsed_package_json, 'dependencies', 'react') then
                return 'typescriptreact'
            end

            return 'typescript'
        else
            if parsed_package_json_has_dependency(parsed_package_json, 'dependencies', 'react') then
                return 'javascriptreact'
            end

            return 'javascript'
        end

        return false
    end

    -- try go
    local root = files.find_root(cwd(path), vim.tbl_flatten { go_project_roots })
    if root then
        for _, ft in ipairs(go_project_roots) do
            if files.file_exists(root .. "/" .. ft) then
                return 'go'
            end
        end
    end

    -- unknown
    return nil
end

function M.get_project_launch_json_path (path)
    local root = files.find_root(cwd(path), vim.tbl_flatten { go_project_roots, package_json_name })

    if not root then
        return nil
    end

    local full_path = root .. launch_json_name
    if files.file_exists(full_path) then
        return full_path
    end

    return nil
end

return M
