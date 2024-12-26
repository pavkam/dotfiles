---@class (exact) dev_icons_custom_icon # A custom icon.
---@field ft string|nil # the file type to get the icon for.
---@field icon string|nil # the icon to use.
---@field color string|nil # the color of the icon.
---@field cterm_color integer|nil # the cterm color of the icon.

return {
    'nvim-tree/nvim-web-devicons',
    lazy = true,
    opts = {
        override = {
            deb = { icon = '', name = 'Deb' },
            lock = { icon = '󰌾', name = 'Lock' },
            mp3 = { icon = '󰎆', name = 'Mp3' },
            mp4 = { icon = '', name = 'Mp4' },
            out = { icon = '', name = 'Out' },
            ['robots.txt'] = { icon = '󰚩', name = 'Robots' },
            ttf = { icon = '', name = 'TrueTypeFont' },
            rpm = { icon = '', name = 'Rpm' },
            woff = { icon = '', name = 'WebOpenFontFormat' },
            woff2 = { icon = '', name = 'WebOpenFontFormat2' },
            xz = { icon = '', name = 'Xz' },
            zip = { icon = '', name = 'Zip' },
        },
        ---@type table<string, dev_icons_custom_icon>
        map = {
            ['eslint'] = { ft = 'javascript', icon = '' },
            ['eslint_d'] = { ft = 'javascript', icon = '' },
            ['prettier'] = { ft = 'javascript', icon = '' },
            ['prettierd'] = { ft = 'javascript', icon = '' },
            ['prettier_d'] = { ft = 'javascript', icon = '' },
            ['rustfmt'] = { ft = 'rust' },
            ['gofmt'] = { ft = 'go' },
            ['gofumpt'] = { ft = 'go' },
            ['gofumports'] = { ft = 'go' },
            ['golines'] = { ft = 'go' },
            ['golangci_lint'] = { ft = 'go' },
            ['vtsls'] = { ft = 'typescript' },
            ['shfmt'] = { ft = 'sh' },
            ['black'] = { ft = 'python' },
            ['isort'] = { ft = 'python' },
            ['csharpier'] = { ft = 'csharp' },
            ['buf'] = { ft = 'proto' },
            ['markdownlint'] = { ft = 'markdown' },
            ['stylua'] = { ft = 'lua' },
            ['luacheck'] = { ft = 'lua' },
            ['lua_ls'] = { ft = 'lua' },
            ['injected'] = { icon = '' },
            ['copilot'] = { icon = '' },
            ['typos_lsp'] = { icon = '' },
        },
    },
    config = function(_, opts)
        local dev_icons = require 'nvim-web-devicons'

        ---@type table<string, dev_icons_custom_icon>
        local custom = opts.map or {}
        opts.map = nil

        dev_icons.setup(opts)

        local new_icons = {}
        for name, mapping in pairs(custom) do
            if mapping.ft then
                local icon, hl = dev_icons.get_icon_by_filetype(mapping.ft, { default = false })
                if icon then
                    local hl_details = hl and ide.theme.get_highlight_group_details(hl) or nil
                    new_icons[name] = {
                        icon = mapping.icon or icon,
                        color = hl_details and hl_details.foreground,
                        cterm_color = hl_details and hl_details.cterm_foreground,
                        name = name,
                    }
                end
            elseif mapping.icon then
                new_icons[name] = {
                    icon = mapping.icon,
                    color = mapping.color,
                    cterm_color = mapping.cterm_color or mapping.color and ide.theme.closest_cterm_color(mapping.color),
                    name = name,
                }
            end
        end

        dev_icons.set_icon(new_icons)
    end,
    init = function()
        ---@module 'nvim-web-devicons'
        local dev_icons = xrequire 'nvim-web-devicons'

        ide.plugin.register_symbol_provider {
            get_file_symbol = function(path)
                xassert {
                    path = { path, { 'string', ['>'] = 0 } },
                }

                if ide.fs.directory_exists(path) then
                    return ''
                end

                local _, base_name, _, compound_extension = ide.fs.split_path(path)
                local text, hl = dev_icons.get_icon(base_name, compound_extension, { default = true })

                return hl and { text, hl = hl } or text
            end,
            get_file_type_symbol = function(file_type)
                xassert {
                    file_type = { file_type, { 'string', ['>'] = 0 } },
                }

                local text, hl = dev_icons.get_icon_by_filetype(file_type, { default = false })
                if not text then
                    text, hl = dev_icons.get_icon(file_type, file_type, { default = true })
                end

                return hl and { text, hl = hl } or text
            end,
        }
    end,
}
