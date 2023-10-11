local utils = require "utils"
local project = require "utils.p"

local M = {}

function M.is_go_project(path)
    local root = project.get_project_root_dir(path)
    return root and utils.any_file_exists(root, { 'go.mod', 'go.sum' }) ~= nil
end

function M.has_golangci_config(path)
    local root = project.get_project_root_dir(path)
    return root and utils.any_file_exists(root, { '.golangci.yml', '.golangci.yaml', '.golangci.toml', '.golangci.json' }) ~= nil
end

return M
