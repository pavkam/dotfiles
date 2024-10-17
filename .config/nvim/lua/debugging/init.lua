local icons = require 'ui.icons'
local keys = require 'core.keys'
local project = require 'project'

local configure_go = require 'debugging.go'
local configure_js = require 'debugging.js'
local configure_python = require 'debugging.python'
local configure_dotnet = require 'debugging.dotnet'

keys.group { lhs = '<leader>d', mode = { 'n', 'v' }, icon = icons.UI.Debugger, desc = 'Debugger' }

-- TODO: Can get the multi-select implementation out of it and the DAP stuff.
-- https://github.com/lucaSartore/nvim-dap-exception-breakpoints/tree/main/lua/nvim-dap-exception-breakpoints

---@class debugging
local M = {}

--- Configures debugging for a given target
---@param target string|integer|nil # the target to configure debugging for
---@return boolean # whether the debugging was configured
local function setup(target)
    local type = project.type(target)
    if vim.tbl_contains({ 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' }, type) then
        configure_js()
    elseif type == 'go' then
        configure_go()
    elseif type == 'python' then
        configure_python()
    elseif type == 'dotnet' then
        configure_dotnet()
    else
        return false
    end

    return true
end

--- Starts or continues debugging for a given target
---@param target string|integer|nil # the target to start or continue debugging for
function M.continue(target)
    local dap = require 'dap'
    local dap_ui = require 'dap.ui'

    local current_session = dap.session()
    if not current_session then
        if not setup(target) then
            vim.error 'No debugging configuration found for this project type.'
            return
        end
    end

    local project_type = project.type(target)
    if not current_session and project_type and #dap.configurations[project_type] > 0 then
        dap_ui.pick_if_many(dap.configurations[project_type], 'Configuration: ', function(i)
            return i.name
        end, function(configuration)
            if configuration then
                vim.info("Starting debugging session '" .. configuration.name .. "' ...")

                dap.run(configuration, { filetype = project_type })
            end
        end)
    elseif current_session then
        vim.info("Resuming debugging session '" .. current_session.config.name .. "' ...")
        dap.continue()
    end
end

--- Gets the dap configurations for a given target
---@param target string|integer|nil # the target to get the dap configurations for
---@return dap.Configuration[] # the dap configurations
function M.configurations(target)
    local dap = require 'dap'

    if not dap.session() then
        if not setup(target) then
            return {}
        end
    end

    local project_type = project.type(target)
    return project_type and dap.configurations[project_type] or {}
end

return M
