-- MainMenu Extension: Turbo Pascal-style menu bar for the IDE.
-- Populates context-sensitive menus (File, Edit, View, Build, Debug, Git, Help)
-- and takes control of vim.o.tabline from the Statusline extension.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local MenuItem = require 'ide.toolkit.MenuItem'
local MenuBar = require 'ide.toolkit.MenuBar'
local Timer = require 'ide.Timer'

local MainMenu = Class('MainMenu', Extension)

function MainMenu:init()
    Extension.init(self, 'MainMenu')
    self._menu_bar = nil ---@type MenuBar|nil
end

-- ── Helpers ──────────────────────────────────────────────────────

--- Check if the current buffer is a normal file buffer (not scratch, not special).
local function has_normal_buf()
    local buf = Buffer.current()
    return buf:is_valid() and buf:is_normal()
end

--- Check if the current buffer has a file path on disk.
local function has_file()
    local buf = Buffer.current()
    return buf:is_valid() and buf:is_normal() and buf:path() ~= nil
end

--- Check if any LSP client is attached to the current buffer.
local function has_lsp()
    local buf = Buffer.current()
    if not buf:is_valid() or not buf:is_normal() then return false end
    local clients = buf:lsp():clients()
    return #clients > 0
end


--- Execute an IDE command if it exists.
local function ide_cmd(name)
    return function()
        pcall(function() IDE.commands:execute(name) end)
    end
end

--- Run an LSP action if available (guarded).
local function lsp_action(action)
    return function()
        if has_lsp() then
            vim.lsp.buf[action]()
        end
    end
end

-- ── Highlights ───────────────────────────────────────────────────

function MainMenu:_define_highlights(ctx)
    -- Menu bar (the top strip)
    ctx:highlight('IDEMenuBar', { bg = '#1e2030', fg = '#565f89' })
    -- Normal menu name in the bar
    ctx:highlight('IDEMenuNormal', { bg = '#1e2030', fg = '#a9b1d6' })
    -- Hovered/active menu name in the bar
    ctx:highlight('IDEMenuActive', { bg = '#3b4261', fg = '#c0caf5', bold = true })
    -- Hotkey underline letter
    ctx:highlight('IDEMenuHotkey', { bg = '#1e2030', fg = '#e0af68', bold = true })
    -- Hovered menu name
    ctx:highlight('IDEMenuHover', { bg = '#292e42', fg = '#c0caf5' })
    -- Dropdown window background
    ctx:highlight('IDEMenuDropdownNormal', { bg = '#1e2030', fg = '#a9b1d6' })
    -- Dropdown border
    ctx:highlight('IDEMenuDropdownBorder', { bg = '#1e2030', fg = '#3b4261' })
    -- Normal dropdown item
    ctx:highlight('IDEMenuItemNormal', { bg = '#1e2030', fg = '#c0caf5' })
    -- Selected/highlighted dropdown item
    ctx:highlight('IDEMenuItemSelected', { bg = '#3b4261', fg = '#c0caf5', bold = true })
    -- Disabled/grayed out item
    ctx:highlight('IDEMenuItemDisabled', { bg = '#1e2030', fg = '#3b4261', italic = true })
    -- Right-aligned shortcut text
    ctx:highlight('IDEMenuShortcut', { bg = '#1e2030', fg = '#565f89' })
    -- Separator line
    ctx:highlight('IDEMenuSeparator', { bg = '#1e2030', fg = '#292e42' })
    -- Icon in menu items
    ctx:highlight('IDEMenuIcon', { bg = '#1e2030', fg = '#7aa2f7' })
    -- Buffer tab highlights in the menu bar
    ctx:highlight('IDEMenuTabActive', { bg = '#3b4261', fg = '#c0caf5', bold = true })
    ctx:highlight('IDEMenuTabInactive', { bg = '#1e2030', fg = '#565f89' })
end

-- ── Menu population ──────────────────────────────────────────────

function MainMenu:_build_file_menu()
    local bar = self._menu_bar
    bar:add_item('File', MenuItem({
        text = 'New', icon = '4',
        action = function() IDE.actions:execute('file.new') end,
    }))
    bar:add_item('File', MenuItem({
        text = 'Open...', icon = '󰝰', shortcut = 'Ctrl+O',
        action = function() IDE.actions:execute('file.open') end,
    }))
    bar:add_item('File', MenuItem({
        text = 'Recent...', icon = '󰋚',
        action = function() IDE.actions:execute('file.recent') end,
    }))
    bar:add_separator('File')
    bar:add_item('File', MenuItem({
        text = 'Save', icon = '󰆓', shortcut = 'Ctrl+S',
        action = function() IDE.actions:execute('file.save') end,
        enabled = has_normal_buf,
    }))
    bar:add_item('File', MenuItem({
        text = 'Save All', icon = '󰆔',
        action = function() IDE.actions:execute('editor.saveAll') end,
    }))
    bar:add_item('File', MenuItem({
        text = 'Save As...', icon = '󰆔', shortcut = 'Ctrl+Shift+S',
        action = function() IDE.actions:execute('file.saveAs') end,
        enabled = has_normal_buf,
    }))
    bar:add_separator('File')
    bar:add_item('File', MenuItem({
        text = 'Rename...', icon = '󰑕',
        action = function() IDE.actions:execute('file.rename') end,
        enabled = has_file,
    }))
    bar:add_item('File', MenuItem({
        text = 'Delete', icon = '󰗨',
        action = function() IDE.actions:execute('file.delete') end,
        enabled = has_file,
    }))
    bar:add_item('File', MenuItem({
        text = 'Copy Path', icon = '󰅍',
        action = function() IDE.actions:execute('file.copyPath') end,
        enabled = has_file,
    }))
    bar:add_separator('File')
    bar:add_item('File', MenuItem({
        text = 'Preferences...', icon = '',
        action = function() IDE.actions:execute('view.options') end,
    }))
    bar:add_item('File', MenuItem({
        text = 'Exit', icon = '󰈆', shortcut = 'Alt+X',
        action = function() IDE.actions:execute('app.quit') end,
    }))
end

function MainMenu:_build_edit_menu()
    local bar = self._menu_bar
    bar:add_item('Edit', MenuItem({
        text = 'Undo', icon = '󰕌', shortcut = 'Ctrl+Z',
        action = function() Buffer.current():undo() end,
        enabled = has_normal_buf,
    }))
    bar:add_item('Edit', MenuItem({
        text = 'Redo', icon = '󰑎', shortcut = 'Ctrl+Y',
        action = function() Buffer.current():redo() end,
        enabled = has_normal_buf,
    }))
    bar:add_separator('Edit')
    bar:add_item('Edit', MenuItem({
        text = 'Select All', icon = '󰒆', shortcut = 'Ctrl+A',
        action = function() IDE.actions:execute('editor.selectAll') end,
        enabled = has_normal_buf,
    }))
    bar:add_item('Edit', MenuItem({
        text = 'Comment Line', icon = '󰅺', shortcut = 'Ctrl+/',
        action = function() IDE.actions:execute('editor.comment') end,
        enabled = has_normal_buf,
    }))
    bar:add_item('Edit', MenuItem({
        text = 'Move Line Up', icon = '󰜸', shortcut = 'Alt+K',
        action = function() IDE.actions:execute('editor.moveLineUp') end,
        enabled = has_normal_buf,
    }))
    bar:add_item('Edit', MenuItem({
        text = 'Move Line Down', icon = '󰜯', shortcut = 'Alt+J',
        action = function() IDE.actions:execute('editor.moveLineDown') end,
        enabled = has_normal_buf,
    }))
    bar:add_item('Edit', MenuItem({
        text = 'Duplicate Line', icon = '󰆑',
        action = function() IDE.actions:execute('editor.duplicateLine') end,
        enabled = has_normal_buf,
    }))
    bar:add_separator('Edit')
    bar:add_item('Edit', MenuItem({
        text = 'Find...', icon = '', shortcut = 'Ctrl+F',
        action = function() IDE.actions:execute('editor.findReplace') end,
    }))
    bar:add_item('Edit', MenuItem({
        text = 'Find in Files', icon = '󰱼', shortcut = 'Ctrl+Shift+F',
        action = function() IDE.actions:execute('file.grep') end,
    }))
    bar:add_item('Edit', MenuItem({
        text = 'Replace', icon = '󰛔', shortcut = 'Ctrl+H',
        action = function() IDE.actions:execute('editor.findReplace') end,
    }))
    bar:add_separator('Edit')
    bar:add_item('Edit', MenuItem({
        text = 'Format', icon = '󰉶', shortcut = 'Ctrl+Shift+I',
        action = function() IDE.actions:execute('lsp.format') end,
        enabled = has_normal_buf,
    }))
    bar:add_item('Edit', MenuItem({
        text = 'Rename Symbol...', icon = '󰑕', shortcut = 'F2',
        action = lsp_action('rename'),
        enabled = has_lsp,
    }))
    bar:add_item('Edit', MenuItem({
        text = 'Quick Fix...', icon = '󰌵', shortcut = 'Alt+Enter',
        action = lsp_action('code_action'),
        enabled = has_lsp,
    }))
    bar:add_separator('Edit')
    bar:add_item('Edit', MenuItem({
        text = 'Toggle Spell Check', icon = '󰓆',
        action = function() IDE.config:toggle('spell_checking') end,
    }))
    bar:add_item('Edit', MenuItem({
        text = 'Toggle Word Wrap', icon = '󰖶',
        action = function()
            local w = Window.current()
            w:set_option('wrap', not w:option('wrap'))
        end,
    }))
end

function MainMenu:_build_view_menu()
    local bar = self._menu_bar
    bar:add_item('View', MenuItem({
        text = 'File Explorer', icon = '󰙅', shortcut = 'Ctrl+E',
        action = function() IDE.actions:execute('file.explorer') end,
    }))
    bar:add_item('View', MenuItem({
        text = 'Go to File...', icon = '', shortcut = 'Ctrl+P',
        action = function() IDE.actions:execute('file.open') end,
    }))
    bar:add_item('View', MenuItem({
        text = 'Search in Files...', icon = '󰱼', shortcut = 'Ctrl+Shift+F',
        action = function() IDE.actions:execute('file.grep') end,
    }))
    bar:add_separator('View')
    bar:add_item('View', MenuItem({
        text = 'Problems', icon = '',
        action = function() IDE.commands:execute('IDEDiagnostics') end,
    }))
    bar:add_item('View', MenuItem({
        text = 'Output', icon = '',
        action = function() IDE.actions:execute('view.quickfix') end,
    }))
    bar:add_item('View', MenuItem({
        text = 'Open Buffers...', icon = '󰈙', shortcut = 'Ctrl+B',
        action = function() IDE.actions:execute('view.buffers') end,
    }))
    bar:add_item('View', MenuItem({
        text = 'Document Outline', icon = '󰙅', shortcut = 'Leader+O',
        action = function() IDE.actions:execute('view.outline') end,
        enabled = function() return Buffer.current():is_normal() end,
    }))
    bar:add_separator('View')
    bar:add_item('View', MenuItem({
        text = 'Toggle Line Numbers', icon = '󰼭',
        action = function()
            local w = Window.current()
            local num = not w:option('number')
            w:set_option('number', num)
            w:set_option('relativenumber', num)
        end,
    }))
    bar:add_item('View', MenuItem({
        text = 'Toggle Whitespace', icon = '󱁐',
        action = function()
            local w = Window.current()
            w:set_option('list', not w:option('list'))
        end,
    }))
    bar:add_separator('View')
    bar:add_item('View', MenuItem({
        text = 'Notifications', icon = '󰂞',
        action = ide_cmd('IDEDismissNotifications'),
    }))
    bar:add_item('View', MenuItem({
        text = 'Symbols...', icon = '',
        action = function()
            pcall(function() IDE.ui.finder:symbols() end)
        end,
        enabled = has_lsp,
    }))
    bar:add_item('View', MenuItem({
        text = 'References...', icon = '',
        action = function()
            pcall(function() IDE.ui.finder:references() end)
        end,
        enabled = has_lsp,
    }))
    bar:add_separator('View')
    bar:add_item('View', MenuItem({
        text = 'Options...', icon = '',
        action = function() IDE.config:manage() end,
    }))
end

function MainMenu:_build_build_menu()
    local bar = self._menu_bar
    bar:clear_menu('Build')

    local proj = IDE:project()
    local ptype = proj and proj:type() or nil

    if ptype == 'go' then
        bar:add_item('Build', MenuItem({
            text = 'Run', icon = '',
            action = function() IDE.shell:floating('go run .') end,
        }))
        bar:add_item('Build', MenuItem({
            text = 'Test', icon = '󰙨',
            action = function() IDE.shell:floating('go test ./...') end,
        }))
        bar:add_item('Build', MenuItem({
            text = 'Build', icon = '',
            action = function() IDE.shell:floating('go build ./...') end,
        }))
        bar:add_item('Build', MenuItem({
            text = 'Go Vet', icon = '󰗀',
            action = function() IDE.shell:floating('go vet ./...') end,
        }))
    elseif ptype == 'typescript' or ptype == 'javascript' then
        bar:add_item('Build', MenuItem({
            text = 'npm run dev', icon = '',
            action = function() IDE.shell:floating('npm run dev') end,
        }))
        bar:add_item('Build', MenuItem({
            text = 'npm test', icon = '󰙨',
            action = function() IDE.shell:floating('npm test') end,
        }))
        bar:add_item('Build', MenuItem({
            text = 'npm run build', icon = '',
            action = function() IDE.shell:floating('npm run build') end,
        }))
        bar:add_item('Build', MenuItem({
            text = 'npm run lint', icon = '',
            action = function() IDE.shell:floating('npm run lint') end,
        }))
    elseif ptype == 'python' then
        bar:add_item('Build', MenuItem({
            text = 'Run File', icon = '',
            action = function()
                local buf = Buffer.current()
                if buf:is_valid() and buf:path() then
                    IDE.shell:floating('python3 ' .. buf:path())
                end
            end,
            enabled = has_file,
        }))
        bar:add_item('Build', MenuItem({
            text = 'pytest', icon = '󰙨',
            action = function() IDE.shell:floating('pytest') end,
        }))
        bar:add_item('Build', MenuItem({
            text = 'mypy', icon = '󰗀',
            action = function() IDE.shell:floating('mypy .') end,
        }))
    elseif ptype == 'rust' then
        bar:add_item('Build', MenuItem({
            text = 'Cargo Run', icon = '',
            action = function() IDE.shell:floating('cargo run') end,
        }))
        bar:add_item('Build', MenuItem({
            text = 'Cargo Test', icon = '󰙨',
            action = function() IDE.shell:floating('cargo test') end,
        }))
        bar:add_item('Build', MenuItem({
            text = 'Cargo Build', icon = '',
            action = function() IDE.shell:floating('cargo build') end,
        }))
        bar:add_item('Build', MenuItem({
            text = 'Cargo Check', icon = '󰗀',
            action = function() IDE.shell:floating('cargo check') end,
        }))
    elseif ptype == 'lua' then
        bar:add_item('Build', MenuItem({
            text = 'Run Tests', icon = '󰙨', shortcut = ':IDETest',
            action = ide_cmd('IDETest'),
        }))
        bar:add_item('Build', MenuItem({
            text = 'Health Check', icon = '󰓙',
            action = function() IDE:healthcheck() end,
        }))
    else
        bar:add_item('Build', MenuItem({
            text = 'No build system detected', icon = '󰋗',
            enabled = function() return false end,
        }))
    end

end

function MainMenu:_build_test_menu()
    local bar = self._menu_bar
    bar:clear_menu('Test')

    bar:add_item('Test', MenuItem({
        text = 'Run Nearest Test', icon = '󰙨',
        action = function()
            pcall(function() require('neotest').run.run() end)
        end,
        enabled = function()
            local ok = pcall(require, 'neotest')
            return ok and has_normal_buf()
        end,
    }))
    bar:add_item('Test', MenuItem({
        text = 'Run Current File Tests', icon = '󰙨',
        action = function()
            pcall(function() require('neotest').run.run(Buffer.current():path()) end)
        end,
        enabled = function()
            local ok = pcall(require, 'neotest')
            return ok and has_file()
        end,
    }))
    bar:add_item('Test', MenuItem({
        text = 'Run All Project Tests', icon = '󰙨',
        action = function()
            pcall(function() require('neotest').run.run(IDE.fs:cwd()) end)
        end,
        enabled = function()
            local ok = pcall(require, 'neotest')
            return ok
        end,
    }))
    bar:add_separator('Test')
    bar:add_item('Test', MenuItem({
        text = 'Run IDE Test Suite', icon = '󰙨', shortcut = ':IDETest',
        action = ide_cmd('IDETest'),
    }))
end

function MainMenu:_build_debug_menu()
    local bar = self._menu_bar
    local function dap_fn(method)
        return function()
            local ok, dap = pcall(require, 'dap')
            if ok then dap[method]() end
        end
    end
    local function has_dap()
        local ok = pcall(require, 'dap')
        return ok
    end

    bar:add_item('Debug', MenuItem({
        text = 'Start / Continue', icon = '', shortcut = 'F5',
        action = dap_fn('continue'), enabled = has_dap,
    }))
    bar:add_item('Debug', MenuItem({
        text = 'Stop', icon = '', shortcut = 'Shift+F5',
        action = dap_fn('terminate'), enabled = has_dap,
    }))
    bar:add_item('Debug', MenuItem({
        text = 'Restart', icon = '󰜉',
        action = dap_fn('restart'), enabled = has_dap,
    }))
    bar:add_separator('Debug')
    bar:add_item('Debug', MenuItem({
        text = 'Toggle Breakpoint', icon = '', shortcut = 'F9',
        action = dap_fn('toggle_breakpoint'), enabled = has_dap,
    }))
    bar:add_item('Debug', MenuItem({
        text = 'Step Over', icon = '󰆹', shortcut = 'F10',
        action = dap_fn('step_over'), enabled = has_dap,
    }))
    bar:add_item('Debug', MenuItem({
        text = 'Step Into', icon = '󰆸', shortcut = 'F11',
        action = dap_fn('step_into'), enabled = has_dap,
    }))
    bar:add_item('Debug', MenuItem({
        text = 'Step Out', icon = '󰆺', shortcut = 'Shift+F11',
        action = dap_fn('step_out'), enabled = has_dap,
    }))
    bar:add_separator('Debug')
    bar:add_item('Debug', MenuItem({
        text = 'Toggle DAP UI', icon = '󰃤',
        action = function()
            pcall(function() require('dapui').toggle() end)
        end,
        enabled = function()
            local ok = pcall(require, 'dapui')
            return ok
        end,
    }))
end

function MainMenu:_build_git_menu()
    local bar = self._menu_bar
    bar:add_item('Git', MenuItem({
        text = 'Lazygit', icon = '', shortcut = 'Ctrl+G',
        action = function()
            pcall(function() IDE.commands:execute('Lazygit') end)
        end,
        enabled = function() return IDE.shell:has('lazygit') end,
    }))
    bar:add_separator('Git')
    bar:add_item('Git', MenuItem({
        text = 'Status', icon = '',
        action = ide_cmd('IDEGit'),
    }))
    bar:add_item('Git', MenuItem({
        text = 'Branches', icon = '',
        action = function()
            pcall(function() IDE.ui.finder:git_branches() end)
        end,
    }))
    bar:add_item('Git', MenuItem({
        text = 'Commits', icon = '',
        action = function()
            pcall(function() IDE.ui.finder:git_commits() end)
        end,
    }))
    bar:add_separator('Git')
    bar:add_item('Git', MenuItem({
        text = 'Stage Hunk', icon = '',
        action = function()
            IDE.git:stage_hunk()
        end,
        enabled = has_file,
    }))
    bar:add_item('Git', MenuItem({
        text = 'Reset Hunk', icon = '󰜺',
        action = function()
            IDE.git:reset_hunk()
        end,
        enabled = has_file,
    }))
    bar:add_item('Git', MenuItem({
        text = 'Blame Line', icon = '',
        action = function()
            IDE.git:blame_line()
        end,
        enabled = has_file,
    }))
    bar:add_separator('Git')
    bar:add_item('Git', MenuItem({
        text = 'Diff File', icon = '',
        action = function()
            pcall(function() IDE.git:diff_this() end)
        end,
        enabled = has_file,
    }))
    bar:add_item('Git', MenuItem({
        text = 'Next Hunk', icon = '󰮱', shortcut = ']c',
        action = function()
            IDE.git:next_hunk()
        end,
        enabled = has_file,
    }))
    bar:add_item('Git', MenuItem({
        text = 'Previous Hunk', icon = '󰮳', shortcut = '[c',
        action = function()
            IDE.git:prev_hunk()
        end,
        enabled = has_file,
    }))
end

function MainMenu:_build_window_menu()
    local bar = self._menu_bar
    bar:clear_menu('Window')

    bar:add_item('Window', MenuItem({
        text = 'Next Window', icon = '󰖲', shortcut = 'F6',
        action = function() IDE.actions:execute('window.cycle') end,
        enabled = function() return IDE.windows:count() > 1 end,
    }))
    bar:add_item('Window', MenuItem({
        text = 'Previous Window', icon = '󰖳', shortcut = 'Shift+F6',
        action = function() Window.cycle_reverse() end,
        enabled = function() return IDE.windows:count() > 1 end,
    }))
    bar:add_separator('Window')
    bar:add_item('Window', MenuItem({
        text = 'Split Horizontal', icon = '󰇙', shortcut = 'Ctrl+W S',
        action = function() IDE.actions:execute('window.splitH') end,
    }))
    bar:add_item('Window', MenuItem({
        text = 'Split Vertical', icon = '󰇚', shortcut = 'Ctrl+W V',
        action = function() IDE.actions:execute('window.splitV') end,
    }))
    bar:add_separator('Window')
    bar:add_item('Window', MenuItem({
        text = 'Maximize', icon = '󰖯',
        action = function()
            if IDE._window_chrome then
                IDE._window_chrome:toggle_maximize(Window.current():id())
            end
        end,
        enabled = function() return IDE.windows:count() > 1 end,
    }))
    bar:add_item('Window', MenuItem({
        text = 'Equal Size', icon = '󰇴',
        action = function() IDE.actions:execute('window.equalize') end,
        enabled = function() return IDE.windows:count() > 1 end,
    }))
    bar:add_item('Window', MenuItem({
        text = 'Close Pane', icon = '󰅖', shortcut = 'Ctrl+W Q',
        action = function()
            if IDE._window_chrome then
                IDE._window_chrome:close_current()
            end
        end,
    }))
    bar:add_item('Window', MenuItem({
        text = 'Close All Others', icon = '󰅗',
        action = function() IDE.actions:execute('window.closeOthers') end,
        enabled = function() return IDE.windows:count() > 1 end,
    }))

    -- Numbered buffer list
    local bufs = IDE.buffers:listed()
    if #bufs > 0 then
        bar:add_separator('Window')
        local cur = Buffer.current()
        local cur_id = cur:is_valid() and cur:id() or -1
        for i, buf in ipairs(bufs) do
            if buf:is_valid() and i <= 9 then
                local name = buf:name() or '[No Name]'
                local check = buf:id() == cur_id and '●' or ' '
                bar:add_item('Window', MenuItem({
                    text = string.format('%s %d  %s', check, i, name),
                    icon = '',
                    action = (function(b)
                        return function()
                            Window.current():set_buffer(b)
                        end
                    end)(buf),
                }))
            end
        end
    end
end

function MainMenu:_build_help_menu()
    local bar = self._menu_bar
    bar:add_item('Help', MenuItem({
        text = 'Command Palette...', icon = '󰘳', shortcut = 'Ctrl+Shift+P',
        action = function() IDE.actions:execute('app.commandPalette') end,
    }))
    bar:add_item('Help', MenuItem({
        text = 'Keymaps', icon = '󰌌',
        action = function()
            pcall(function() IDE.ui.finder:keymaps() end)
        end,
    }))
    bar:add_item('Help', MenuItem({
        text = 'IDE Status', icon = '󰋼',
        action = ide_cmd('IDEStatus'),
    }))
    bar:add_item('Help', MenuItem({
        text = 'LSP Info', icon = '',
        action = ide_cmd('IDELsp'),
    }))
    bar:add_item('Help', MenuItem({
        text = 'Extensions', icon = '',
        action = ide_cmd('IDEExtensions'),
    }))
    bar:add_separator('Help')
    bar:add_item('Help', MenuItem({
        text = 'Health Check', icon = '󰓙',
        action = function() IDE:healthcheck() end,
    }))
    bar:add_item('Help', MenuItem({
        text = 'Neovim Help', icon = '󰋖',
        action = function() IDE:help() end,
    }))
    bar:add_item('Help', MenuItem({
        text = 'About IDE', icon = '󰋼',
        action = function()
            local ext_count = #IDE:extensions()
            local lsp_count = #IDE.lsp:active()
            IDE.ui:info(string.format(
                '  **TurboVision IDE**\n\n' ..
                '  Built on Neovim %s\n' ..
                '  %d extensions loaded\n' ..
                '  %d language servers active',
                vim.version().major .. '.' .. vim.version().minor .. '.' .. vim.version().patch,
                ext_count, lsp_count))
        end,
    }))
end

-- ── Registration ─────────────────────────────────────────────────

function MainMenu:on_register(ctx)
    self:_define_highlights(ctx)

    -- Create the menu bar
    self._menu_bar = MenuBar()
    IDE.menu_bar = self._menu_bar
    self._menu_bar:enable_mouse()

    -- Register top-level menus in order
    self._menu_bar:add_menu('&File')
    self._menu_bar:add_menu('&Edit')
    self._menu_bar:add_menu('&View')
    self._menu_bar:add_menu('&Build')
    self._menu_bar:add_menu('&Test')
    self._menu_bar:add_menu('&Debug')
    self._menu_bar:add_menu('&Git')
    self._menu_bar:add_menu('&Window')
    self._menu_bar:add_menu('&Help')

    -- Populate static menus
    self:_build_file_menu()
    self:_build_edit_menu()
    self:_build_view_menu()
    self:_build_build_menu()
    self:_build_test_menu()
    self:_build_debug_menu()
    self:_build_git_menu()
    self:_build_window_menu()
    self:_build_help_menu()

    -- Take over tabline from the statusline extension
    local Dispatch = require 'ide.Dispatch'
    Dispatch.renderer('menubar', function() return self._menu_bar:render() end)
    IDE.config:set_option('showtabline', 2)
    IDE.config:set_option('tabline', '%!v:lua.IDE_render_menubar()')

    -- Alt+key accelerators are auto-registered by MenuBar:add_menu() from & notation

    -- F10 opens the first menu (classic Borland behavior)
    ctx:keymap('n', '<F10>', function()
        if self._menu_bar:is_open() then
            self._menu_bar:close()
        else
            self._menu_bar:open('File')
        end
    end, { desc = 'Open menu bar' })

    -- Rebuild context-sensitive menus on buffer/LSP changes
    local rebuild = Timer.debounce(100, function()
        self:_build_build_menu()
        self:_build_window_menu()
        IDE.ui:redraw_tabline()
    end)

    ctx:hook({ 'BufEnter', 'LspAttach', 'LspDetach' }, function()
        rebuild()
    end, { desc = 'MainMenu: rebuild context menus' })

    -- IDEMenu command for programmatic access
    ctx:command('IDEMenu', function(opts)
        local args = opts.fargs or {}
        local menu_name = args[1]
        if menu_name then
            self._menu_bar:open(menu_name)
        else
            self._menu_bar:open('File')
        end
    end, { desc = 'Open IDE menu', nargs = '?' })
end

function MainMenu:on_unregister()
    -- Restore the tabline to the statusline extension's tabbar
    if IDE.tabbar then
        Dispatch.renderer('tabbar', function() return IDE.tabbar:render() end)
        IDE.config:set_option('tabline', '%!v:lua.IDE_render_tabbar()')
    end
    IDE.menu_bar = nil
    self._menu_bar = nil
end

--- Expose for ctx:menu() slot usage from other extensions.
---@return MenuBar|nil
function MainMenu:menu_bar()
    return self._menu_bar
end

return MainMenu
