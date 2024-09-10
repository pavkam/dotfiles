return {
    'nvim-lualine/lualine.nvim',
    cond = not vim.headless,
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    },
    event = 'UIEnter',
    opts = function()
        local lualine_sections = require 'ui.lualine-sections'

        --- Merge two tables
        ---@param base table
        ---@param add table
        local function with(base, add)
            return vim.tbl_merge(base, add)
        end

        return {
            options = {
                globalstatus = true,
                theme = 'auto',
            },
            tabline = {
                lualine_a = {
                    lualine_sections.branch,
                    with(lualine_sections.file_type, {
                        separator = '',
                        padding = { left = 1, right = 0 },
                    }),
                    lualine_sections.diff,
                    lualine_sections.diagnostics,
                },
                lualine_b = {
                    lualine_sections.buffers,
                },
                lualine_c = {},
                lualine_x = {},
                lualine_y = {},
                lualine_z = { lualine_sections.tabs },
            },
            sections = {
                lualine_a = {
                    lualine_sections.mode,
                    lualine_sections.macro,
                },
                lualine_b = {
                    with(lualine_sections.copilot, { separator = false, padding = { left = 1, right = 0 } }),
                },
                lualine_c = {
                    lualine_sections.lsp,
                    lualine_sections.linting,
                    lualine_sections.formatting,
                    lualine_sections.neotest,
                    lualine_sections.package_info,
                    lualine_sections.shell,
                    lualine_sections.workspace_diagnostics,
                },
                lualine_x = {},
                lualine_y = {
                    lualine_sections.debugger,
                },
                lualine_z = {
                    with(lualine_sections.ignore_hidden_files, { separator = false }),
                    with(lualine_sections.tmux, { separator = false }),
                    with(lualine_sections.spell_check, { separator = false }),
                    with(lualine_sections.typo_check, { separator = false }),
                    lualine_sections.lazy_updates,
                    with(lualine_sections.progress, { separator = ' ', padding = { left = 1, right = 0 } }),
                    with(lualine_sections.location, { left = 0, right = 1 }),
                },
            },
            extensions = { 'neo-tree', 'lazy', 'man', 'mason', 'nvim-dap-ui', 'quickfix' },
        }
    end,
}
