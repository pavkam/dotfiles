local icons = require 'icons'

return {
    'williamboman/mason.nvim',
    cond = not ide.process.is_headless,
    cmd = {
        'Mason',
        'MasonInstall',
        'MasonUninstall',
        'MasonUninstallAll',
        'MasonLog',
    },
    build = ':MasonUpdate',
    opts = {
        ui = {
            icons = {
                package_installed = icons.Dependencies.Installed,
                package_uninstalled = icons.Dependencies.Uninstalled,
                package_pending = icons.Dependencies.Pending,
            },
            border = vim.g.border_style,
        },
        ensure_installed = {
            -- shell
            'shellcheck',
            'shfmt',
            -- docker
            'hadolint',
            -- lua
            'luacheck',
            'stylua',
            -- proto
            'buf',
            -- python
            'black',
            'isort',
            'debugpy',
            -- go
            'golines',
            'gofumpt',
            'goimports',
            'goimports-reviser',
            'golangci-lint',
            'staticcheck',
            'delve',
            'gomodifytags',
            'impl',
            'iferr',
            'gotests',
            'gotestsum',
            -- js
            'eslint_d',
            'prettier',
            'prettierd',
            'js-debug-adapter',
            'jsonlint',
            -- csharp
            'csharpier',
            'netcoredbg',
            -- markdown
            'markdownlint',
            -- python,
            'ruff',
            -- general
            'typos-lsp',
        },
    },
    config = function(_, opts)
        require('mason').setup(opts)

        local mr = require 'mason-registry'

        -- trigger FileType event to possibly load this newly installed LSP server
        mr:on('package:install:success', function()
            vim.defer_fn(function()
                vim.api.nvim_exec_autocmds('FileType', {
                    buffer = vim.api.nvim_get_current_buf(),
                    modeline = false,
                })
            end, 100)
        end)

        local function ensure_installed()
            for _, tool in ipairs(opts.ensure_installed) do
                local p = mr.get_package(tool)
                if not p:is_installed() then
                    p:install()
                end
            end
        end

        if mr.refresh then
            mr.refresh(ensure_installed)
        else
            ensure_installed()
        end
    end,
}
