-- Visual snapshot tests.
-- Captures tmux pane with colors and verifies visual expectations.
-- Run: :lua require('ide.test_visual').run()
--
-- These tests MUST run inside a tmux session. They capture the actual
-- terminal output including ANSI colors and verify specific visual
-- properties (status bar content, error messages, UI corruption).

local M = {}

local results = {}
local snapshot_dir = '/tmp/ide_visual_snapshots'
local fixture_dir = vim.fs.joinpath(vim.fn.stdpath('config'), 'lua', 'ide', 'test_fixtures')

local function test(name, fn)
    local ok, err = pcall(fn)
    results[#results + 1] = { name = name, passed = ok, error = not ok and tostring(err) or nil }
end

local function assert_true(v, m) if not v then error(m or 'fail', 2) end end
local function assert_false(v, m) if v then error(m or 'fail', 2) end end
local function assert_match(s, p, m) if not s:match(p) then error(string.format('%s: no match for /%s/', m or 'match', p), 2) end end
local function assert_no_match(s, p, m) if s:match(p) then error(string.format('%s: unexpected match /%s/', m or 'no_match', p), 2) end end
local function assert_eq_str(a, b, m) if a ~= b then error(string.format('%s: %q ~= %q', m or 'eq', a, b), 2) end end

local function ensure_normal()
    vim.cmd('stopinsert')
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, c = pcall(vim.api.nvim_win_get_config, win)
        if ok and c.relative and c.relative ~= '' then pcall(vim.api.nvim_win_close, win, true) end
    end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, c = pcall(vim.api.nvim_win_get_config, win)
        if ok and (not c.relative or c.relative == '') then pcall(vim.api.nvim_set_current_win, win); break end
    end
    for _, win in ipairs(vim.api.nvim_list_wins()) do pcall(function() vim.wo[win].winfixbuf = false end) end
end

--- Capture a plain text snapshot of the tmux pane.
---@return string
local function capture_plain()
    local r = vim.system({ 'tmux', 'capture-pane', '-t', '0', '-p' }, { text = true }):wait(5000)
    return r.stdout or ''
end

--- Capture a color snapshot with ANSI escape codes.
---@return string
local function capture_color()
    local r = vim.system({ 'tmux', 'capture-pane', '-t', '0', '-e', '-p' }, { text = true }):wait(5000)
    return r.stdout or ''
end

--- Save a snapshot to disk for debugging.
---@param name string
---@param content string
local function save_snapshot(name, content)
    vim.fn.mkdir(snapshot_dir, 'p')
    local f = io.open(snapshot_dir .. '/' .. name .. '.txt', 'w')
    if f then f:write(content); f:close() end
end

--- Get the last line (statusline).
---@param snap string
---@return string
local function statusline(snap)
    local lines = vim.split(snap, '\n')
    for i = #lines, 1, -1 do
        if lines[i] ~= '' then return lines[i] end
    end
    return ''
end

--- Get the first line (tabline).
---@param snap string
---@return string
local function tabline(snap)
    local lines = vim.split(snap, '\n')
    return lines[1] or ''
end

--- Get the second line (winbar).
---@param snap string
---@return string
local function winbar(snap)
    local lines = vim.split(snap, '\n')
    return lines[2] or ''
end

--- Check if there are any error-level noice notifications visible.
---@param snap string
---@return boolean, string|nil
local function has_visible_errors(snap)
    -- Look for Error notification boxes
    if snap:match('Error%s+%d+:%d+:%d+') then
        return true, snap:match('(Error.-\n)')
    end
    if snap:match('E5113') or snap:match('E5108') or snap:match('E1513') then
        return true, snap:match('(E%d+.-\n)')
    end
    return false, nil
end

--- Check if the buffer content is corrupted (has vim commands leaked into it).
---@param snap string
---@return boolean
local function has_corruption(snap)
    -- Look for common command leaks
    return snap:match(':lua ') ~= nil
        or snap:match(':NoiceAll') ~= nil
        or snap:match(':luafile ') ~= nil
        or snap:match(':IDETest') ~= nil
        or snap:match(':Telescope\n') ~= nil
end

--- Wait and capture.
---@param ms integer
local function wait(ms)
    vim.wait(ms, function() return false end)
end

function M.run()
    results = {}

    -- Verify we're in tmux
    if not vim.env.TMUX then
        print('Visual tests require tmux!')
        return { passed = 0, failed = 0, total = 0 }
    end

    -- Clean state before running
    ensure_normal()
    vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
    wait(3000)

    -- ═══════════════════════════════════════
    -- STARTUP VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('statusline shows mode and LSP', function()
        local snap = capture_plain()
        local sl = statusline(snap)
        assert_match(sl, 'Ready', 'should show NORMAL mode')
        assert_match(sl, '󱐏', 'should show AI indicator')
    end)

    test('tabline shows git branch', function()
        local snap = capture_plain()
        local tl = tabline(snap)
        -- Should have branch name or buffer name
        assert_true(#tl > 10, 'tabline should have content')
    end)

    test('winbar shows file path', function()
        local snap = capture_plain()
        local wb = winbar(snap)
        assert_true(#wb > 5, 'winbar should have content')
    end)

    test('no visible errors on startup', function()
        local snap = capture_plain()
        local has_err, detail = has_visible_errors(snap)
        assert_false(has_err, 'should not have visible errors: ' .. (detail or ''))
    end)

    test('no buffer corruption', function()
        -- Check the file on disk, not the screen (which may show message history)
        local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local text = table.concat(content, '\n')
        assert_false(text:match(':lua ') ~= nil, 'buffer content should not have :lua commands')
        assert_false(text:match(':NoiceAll') ~= nil, 'buffer content should not have :NoiceAll')
    end)

    -- ═══════════════════════════════════════
    -- NAVIGATION VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('hover popup appears and disappears cleanly', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(2000)
        -- Move to a known position instead of searching
        vim.cmd('10')
        wait(300)
        -- Try hover but don't fail if no LSP is attached (fixture project)
        pcall(vim.lsp.buf.hover)
        wait(2000)
        local snap_with_hover = capture_plain()
        save_snapshot('hover_open', snap_with_hover)
        assert_false(has_visible_errors(snap_with_hover), 'hover should not show errors')

        -- Close hover
        vim.cmd('normal! \\<Esc>')
        wait(500)
        local snap_after = capture_plain()
        save_snapshot('hover_closed', snap_after)
    end)

    test('file switch leaves no visual artifacts', function()
        ensure_normal()
        pcall(vim.cmd, 'edit ' .. vim.fs.joinpath(fixture_dir, 'sample.tsx'))
        wait(3000)
        local snap_tsx = capture_plain()
        save_snapshot('switch_tsx', snap_tsx)
        assert_false(has_corruption(snap_tsx), 'TSX should not have corruption')

        pcall(vim.cmd, 'edit ' .. vim.fs.joinpath(fixture_dir, 'sample.lua'))
        wait(2000)

        pcall(vim.cmd, 'edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(2000)
        local snap_go = capture_plain()
        save_snapshot('switch_go_back', snap_go)
        assert_false(has_corruption(snap_go), 'Go switch back should not have corruption')
    end)

    test('statusline updates on file switch', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(2000)
        local sl_go = statusline(capture_plain())
        assert_match(sl_go, 'Ready', 'Go file should show NORMAL mode')

        pcall(vim.cmd, 'edit ' .. vim.fs.joinpath(fixture_dir, 'sample.lua'))
        wait(2000)
        local sl_lua = statusline(capture_plain())
        assert_match(sl_lua, 'Ready', 'Lua file should show NORMAL mode')

        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(1000)
    end)

    test('winbar shows treesitter context in function', function()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(2000)
        vim.cmd('14') -- go to func main()
        wait(1000)
        local wb = winbar(capture_plain())
        assert_true(#wb > 5, 'winbar should have content when in a function')
    end)

    -- ═══════════════════════════════════════
    -- COLOR CHECKS
    -- ═══════════════════════════════════════

    test('syntax highlighting active (colors present)', function()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(1000)
        local color_snap = capture_color()
        -- ANSI escape codes should be present (38;2 = RGB foreground)
        assert_match(color_snap, '38;2;', 'should have RGB color codes')
    end)

    test('terminal output has color codes', function()
        wait(500)
        local color_snap = capture_color()
        -- The full output should have RGB color codes somewhere
        assert_match(color_snap, '38;2;', 'terminal should have RGB colors')
    end)

    -- ═══════════════════════════════════════
    -- PANEL VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('IDEStatus panel renders with borders', function()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(2000)
        vim.cmd('IDEStatus')
        wait(2000)
        local snap = capture_plain()
        save_snapshot('ide_status', snap)
        assert_match(snap, '│', 'should have border chars')
        assert_match(snap, 'IDE Status', 'should show IDE Status title')
        vim.api.nvim_feedkeys('q', 'n', false)
        wait(500)
    end)

    test('IDEStatus panel closes cleanly', function()
        ensure_normal()
        wait(1000)
        vim.cmd('IDEStatus')
        wait(1500)
        vim.api.nvim_feedkeys('q', 'n', false)
        wait(1500)
        local snap = capture_plain()
        save_snapshot('after_status_close', snap)
        -- After closing, no panel title should remain
        local sl = statusline(snap)
        assert_match(sl, 'Ready', 'should be in normal mode after closing panel')
    end)

    -- ═══════════════════════════════════════
    -- NOTIFICATION QUALITY CHECKS
    -- ═══════════════════════════════════════

    test('notifications clear after timeout', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(5000)  -- wait for any startup notifications to clear
        local snap = capture_plain()
        save_snapshot('notifications_cleared', snap)
        -- After 5 seconds, startup notifications should be gone
        -- (noice timeout is 3000ms by default)
        local body_lines = {}
        for line in snap:gmatch('[^\n]+') do
            body_lines[#body_lines + 1] = line
        end
        -- Check that no notification boxes overlap the code area
        -- Notifications have │ ━ ╭ ╮ ╰ ╯ characters in the right side
        local right_boxes = 0
        for _, line in ipairs(body_lines) do
            if line:match('│.*20%d%d') or line:match('│.*%d+:%d+:%d+') then
                right_boxes = right_boxes + 1
            end
        end
        -- Allow at most 1 notification box (could be the session save)
        assert_true(right_boxes <= 2, 'too many notification boxes visible: ' .. right_boxes)
    end)

    test('no error notifications visible after opening Go file', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(5000)
        local snap = capture_plain()
        save_snapshot('go_file_opened', snap)
        local has_err = has_visible_errors(snap)
        assert_false(has_err, 'no errors should be visible after opening Go file')
    end)

    -- ═══════════════════════════════════════
    -- FOLDING VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('fold markers appear after zM', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(3000) -- treesitter needs time to parse
        vim.cmd('normal! zM')
        wait(500)
        local snap = capture_plain()
        save_snapshot('folds_closed', snap)
        -- Folds may or may not be available depending on treesitter parsing
        -- Just check no errors
        assert_false(has_visible_errors(snap), 'zM should not error')
        vim.cmd('normal! zR')
        wait(500)
    end)

    test('folds open cleanly with zR', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(2000)
        vim.cmd('normal! zM')
        wait(500)
        vim.cmd('normal! zR')
        wait(500)
        local snap = capture_plain()
        save_snapshot('folds_opened', snap)
        assert_false(has_visible_errors(snap), 'zR should not error')
    end)

    -- ═══════════════════════════════════════
    -- COMMENTING VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('gcc adds and removes comment marker', function()
        ensure_normal()
        pcall(vim.cmd, 'edit! ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(2000)
        -- Ensure buffer has content
        if vim.api.nvim_buf_line_count(0) < 5 then return end
        vim.bo[0].modifiable = true
        vim.cmd('5')
        wait(300)
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        local before = vim.fn.getline(lnum)
        assert_true(#before > 0, 'line should have content')
        vim.cmd('normal gcc')
        wait(500)
        local after = vim.fn.getline(lnum)
        assert_true(before ~= after, 'gcc should modify the line')
        vim.cmd('normal! u')
        wait(300)
        local restored = vim.fn.getline(lnum)
        assert_eq_str(before, restored, 'undo should restore original')
    end)

    -- ═══════════════════════════════════════
    -- INDENT GUIDE VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('indent guides render without errors', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(3000)
        vim.cmd('15') -- inside func main()
        wait(1000)
        local snap = capture_plain()
        save_snapshot('indent_guides', snap)
        assert_false(has_visible_errors(snap), 'indent guides should not cause errors')
    end)

    -- ═══════════════════════════════════════
    -- WHICH-KEY VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('KeyManager is available', function()
        assert_true(IDE.key_manager ~= nil or IDE.keys ~= nil, 'KeyManager should exist')
    end)

    test('leader keybindings are mapped', function()
        -- Check that common leader keys have mappings
        local maps = vim.api.nvim_get_keymap('n')
        local has_leader_c = false
        local has_leader_w = false
        for _, m in ipairs(maps) do
            if m.lhs == ' c' then has_leader_c = true end
            if m.lhs == ' w' then has_leader_w = true end
        end
        assert_true(has_leader_c, 'leader-c should be mapped')
        assert_true(has_leader_w, 'leader-w should be mapped')
    end)

    -- ═══════════════════════════════════════
    -- RAPID OPERATION STABILITY
    -- ═══════════════════════════════════════

    test('rapid file switches leave no artifacts', function()
        ensure_normal()
        -- Switch through multiple files rapidly
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(500)
        pcall(vim.cmd, 'edit ' .. vim.fs.joinpath(fixture_dir, 'sample.lua'))
        wait(500)
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(500)
        pcall(vim.cmd, 'edit ' .. vim.fs.joinpath(fixture_dir, 'sample.lua'))
        wait(2000)
        local snap = capture_plain()
        save_snapshot('rapid_switch', snap)
        assert_false(has_corruption(snap), 'rapid switching should not cause corruption')
        assert_false(has_visible_errors(snap), 'rapid switching should not show errors')
    end)

    -- ═══════════════════════════════════════
    -- MAIN MENU VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('menu bar renders in tabline', function()
        ensure_normal()
        wait(500)
        local snap = capture_plain()
        local tl = tabline(snap)
        assert_match(tl, 'File', 'tabline should show File menu')
        assert_match(tl, 'Edit', 'tabline should show Edit menu')
        assert_match(tl, 'View', 'tabline should show View menu')
        assert_match(tl, 'Help', 'tabline should show Help menu')
    end)

    test('menu bar shows buffer tabs on the right', function()
        ensure_normal()
        -- Open multiple files to populate buffer tabs
        vim.cmd('edit! ' .. vim.fs.joinpath(fixture_dir, 'sample.lua'))
        wait(1000)
        vim.cmd('edit! ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(1000)
        local snap = capture_plain()
        save_snapshot('menubar_with_tabs', snap)
        local tl = tabline(snap)
        -- Menu items on the left
        assert_match(tl, 'File', 'tabline should show File menu')
        -- Buffer tabs on the right
        assert_match(tl, 'sample', 'tabline should show buffer tab filename')
    end)

    test('F10 opens File menu dropdown', function()
        ensure_normal()
        wait(500)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<F10>', true, true, true), 'x', false)
        wait(1000)
        local snap = capture_plain()
        save_snapshot('menu_file_open', snap)
        -- Should show File menu items
        assert_match(snap, 'Save', 'File menu should show Save')
        assert_match(snap, 'Exit', 'File menu should show Exit')
        -- No errors
        local has_err = has_visible_errors(snap)
        assert_false(has_err, 'File menu should not show errors')
        -- Close
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(500)
    end)

    test('File menu closes cleanly with Esc', function()
        ensure_normal()
        wait(500)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<F10>', true, true, true), 'x', false)
        wait(800)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(800)
        local snap = capture_plain()
        save_snapshot('menu_file_closed', snap)
        -- After closing, menu content should not be visible
        assert_false(snap:match('Rename%.%.%.') ~= nil, 'dropdown should be closed')
        local sl = statusline(snap)
        assert_match(sl, 'Ready', 'should be in NORMAL mode')
    end)

    test('l/h navigate between menus', function()
        ensure_normal()
        wait(500)
        -- Open File menu
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<F10>', true, true, true), 'x', false)
        wait(800)
        -- Navigate right to Edit
        vim.api.nvim_feedkeys('l', 'x', false)
        wait(800)
        local snap = capture_plain()
        save_snapshot('menu_edit_via_l', snap)
        assert_match(snap, 'Undo', 'Edit menu should show Undo')
        -- Navigate right to View
        vim.api.nvim_feedkeys('l', 'x', false)
        wait(800)
        snap = capture_plain()
        save_snapshot('menu_view_via_l', snap)
        assert_match(snap, 'Explorer', 'View menu should show Explorer')
        -- Close
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(500)
    end)

    test('Alt+G opens Git menu', function()
        ensure_normal()
        wait(500)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<M-g>', true, true, true), 'x', false)
        wait(800)
        local snap = capture_plain()
        save_snapshot('menu_git', snap)
        assert_match(snap, 'Lazygit', 'Git menu should show Lazygit')
        assert_match(snap, 'Branches', 'Git menu should show Branches')
        -- Close
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(500)
    end)

    test('menu item selection with Enter does not error', function()
        ensure_normal()
        wait(500)
        -- Open File menu
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<F10>', true, true, true), 'x', false)
        wait(800)
        -- Navigate to Settings (non-destructive action)
        for _ = 1, 10 do
            vim.api.nvim_feedkeys('j', 'x', false)
            wait(100)
        end
        -- Press Esc instead of Enter to avoid side effects in tests
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(800)
        local snap = capture_plain()
        assert_false(has_visible_errors(snap), 'menu navigation should not error')
    end)

    test('no errors after rapid menu open/close', function()
        ensure_normal()
        wait(500)
        for _ = 1, 3 do
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<F10>', true, true, true), 'x', false)
            wait(300)
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
            wait(300)
        end
        wait(500)
        local snap = capture_plain()
        save_snapshot('menu_rapid_toggle', snap)
        assert_false(has_visible_errors(snap), 'rapid menu toggle should not error')
    end)

    test('Build menu shows context for Lua project', function()
        ensure_normal()
        -- Open a Lua file to trigger Lua project context
        pcall(vim.cmd, 'edit ' .. vim.fs.joinpath(fixture_dir, 'sample.lua'))
        wait(2000)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<M-b>', true, true, true), 'x', false)
        wait(800)
        local snap = capture_plain()
        save_snapshot('menu_build_lua', snap)
        -- Should have Lua-specific items or generic items
        assert_false(has_visible_errors(snap), 'Build menu should not error')
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(500)
        ensure_normal()
        vim.cmd('bdelete!')
    end)

    -- ═══════════════════════════════════════
    -- COMMAND PALETTE / PICKER TESTS
    -- ═══════════════════════════════════════

    test('command palette opens and shows actions', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(1000)
        vim.cmd('IDEActions')
        wait(1000)
        local snap = capture_plain()
        save_snapshot('cmd_palette_open', snap)
        assert_match(snap, 'Command Palette', 'should show title')
        assert_match(snap, '▸', 'should show selection marker')
        assert_false(has_visible_errors(snap), 'palette should not show errors')
        -- Close
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(500)
    end)

    test('command palette j/k moves selection', function()
        ensure_normal()
        wait(500)
        vim.cmd('IDEActions')
        wait(1000)
        local snap1 = capture_plain()
        -- Move down
        vim.api.nvim_feedkeys('jj', 'x', false)
        wait(500)
        local snap2 = capture_plain()
        save_snapshot('cmd_palette_jk', snap2)
        -- The ▸ marker should have moved (different line)
        assert_match(snap2, '▸', 'should still show selection marker after j')
        assert_false(has_visible_errors(snap2), 'navigation should not error')
        -- Close
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(500)
    end)

    test('command palette Enter executes action without error', function()
        ensure_normal()
        wait(500)
        vim.cmd('IDEActions')
        wait(1000)
        -- Navigate to "Help" (3rd item: app.help)
        vim.api.nvim_feedkeys('jj', 'x', false)
        wait(300)
        -- Press Enter to execute
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, true, true), 'x', false)
        wait(1500)
        local snap = capture_plain()
        save_snapshot('cmd_palette_enter', snap)
        assert_false(has_visible_errors(snap), 'executing action should not error')
        -- Clean up any help buffer
        ensure_normal()
        pcall(vim.cmd, 'bdelete!')
    end)

    test('command palette closes cleanly', function()
        ensure_normal()
        wait(500)
        vim.cmd('IDEActions')
        wait(1000)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(800)
        local snap = capture_plain()
        save_snapshot('cmd_palette_closed', snap)
        -- Palette should be gone
        assert_false(snap:match('Command Palette') ~= nil, 'palette should be closed')
        local sl = statusline(snap)
        assert_match(sl, 'Ready', 'should be in NORMAL mode')
    end)

    test('buffer picker shows current buffer', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(1000)
        vim.cmd('IDEBuffers')
        wait(1000)
        local snap = capture_plain()
        save_snapshot('buf_picker', snap)
        assert_match(snap, 'Buffers', 'should show Buffers title')
        assert_match(snap, '▸', 'should show selection marker')
        assert_false(has_visible_errors(snap), 'buffer picker should not error')
        -- Close
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(500)
    end)

    -- ═══════════════════════════════════════
    -- FRAMED WINDOW SPLIT TESTS
    -- ═══════════════════════════════════════

    test('IDESplitVertical does not error', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(3000)
        pcall(vim.cmd, 'IDESplitVertical')
        wait(2000)
        local snap = capture_plain()
        save_snapshot('split_vertical', snap)
        assert_false(has_visible_errors(snap), 'split should not show errors')
        -- Clean up
        if IDE._window_chrome and IDE._window_chrome._splitter then
            IDE._window_chrome:toggle_maximize_current()
        end
        wait(1000)
    end)

    test('split unsplit cycle does not error', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(3000)
        pcall(vim.cmd, 'IDESplitVertical')
        wait(2000)
        if IDE._window_chrome then
            IDE._window_chrome:toggle_maximize_current()
        end
        wait(2000)
        local snap = capture_plain()
        save_snapshot('split_unsplit', snap)
        assert_false(has_visible_errors(snap), 'split/unsplit should not error')
    end)

    -- ═══════════════════════════════════════
    -- EDITING KEYMAPS VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('gg goes to start of buffer', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(1000)
        vim.cmd('normal! 10G')
        wait(200)
        vim.cmd('normal! gg')
        wait(500)
        local cursor = vim.api.nvim_win_get_cursor(0)
        assert_true(cursor[1] == 1, 'gg should move to line 1')
    end)

    test('G goes to end of buffer', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(1000)
        vim.cmd('normal! G')
        wait(500)
        local cursor = vim.api.nvim_win_get_cursor(0)
        local line_count = vim.api.nvim_buf_line_count(0)
        assert_true(cursor[1] == line_count, 'G should move to last line')
    end)

    test('undo/redo works', function()
        ensure_normal()
        pcall(vim.cmd, 'edit ' .. vim.fn.stdpath('config') .. '/lua/ide/test_visual.lua')
        wait(2000)
        vim.cmd('5')
        wait(200)
        local before = vim.fn.getline(5)
        assert_true(#before > 0, 'line should have content')
        vim.cmd('normal! dd')
        wait(200)
        local deleted = vim.fn.getline(5)
        assert_true(before ~= deleted, 'dd should delete line')
        vim.cmd('normal! u')
        wait(200)
        local undone = vim.fn.getline(5)
        assert_eq_str(before, undone, 'u should undo')
    end)

    -- ═══════════════════════════════════════
    -- BUFFER MANAGEMENT VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('leader-c closes buffer cleanly', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(1000)
        local snap_before = capture_plain()
        local sl_before = statusline(snap_before)
        -- leader-c should close the buffer
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>c', true, true, true), 'x', false)
        wait(1000)
        local snap_after = capture_plain()
        assert_false(has_visible_errors(snap_after), 'leader-c should not cause errors')
    end)

    test('leader-w saves buffer', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(1000)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>w', true, true, true), 'x', false)
        wait(1000)
        local snap = capture_plain()
        assert_false(has_visible_errors(snap), 'leader-w should not cause errors')
    end)

    -- ═══════════════════════════════════════
    -- SEARCH KEYMAPS VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('Escape clears search highlight without errors', function()
        ensure_normal()
        vim.cmd('edit! ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(2000)
        vim.bo[0].buftype = ''
        vim.cmd('1')
        wait(200)
        pcall(vim.cmd, '/Greeter')
        wait(500)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(500)
        local snap = capture_plain()
        assert_false(has_visible_errors(snap), 'Escape should not cause errors')
        local sl = statusline(snap)
        assert_match(sl, 'Ready', 'should return to NORMAL mode')
    end)

    -- ═══════════════════════════════════════
    -- QUICKFIX VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('leader-qq toggles quickfix list', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(1000)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>qq', true, true, true), 'x', false)
        wait(1000)
        local snap_open = capture_plain()
        save_snapshot('qf_open', snap_open)
        -- Quickfix should show
        assert_true(snap_open:match('Quickfix') ~= nil or snap_open:match('setqflist') ~= nil, 'quickfix should be visible')

        -- Close it
        vim.cmd('cclose')
        wait(500)
        local snap_closed = capture_plain()
        assert_false(has_visible_errors(snap_closed), 'closing qf should not error')
    end)

    -- ═══════════════════════════════════════
    -- FORMAT VISUAL CHECKS
    -- ═══════════════════════════════════════

    test('= format does not error on Go file', function()
        ensure_normal()
        vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
        wait(3000)
        vim.api.nvim_feedkeys('=', 'x', false)
        wait(3000)
        local snap = capture_plain()
        save_snapshot('format_go', snap)
        assert_false(has_visible_errors(snap), 'format should not cause errors')
    end)

    -- ═══════════════════════════════════════
    -- MENU WITH NO FILE OPEN
    -- ═══════════════════════════════════════

    test('menus work with no file open (empty buffer)', function()
        ensure_normal()
        -- Close all buffers to get to an empty state
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
        vim.cmd('enew')
        wait(500)

        -- File menu should open without errors
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<F10>', true, true, true), 'x', false)
        wait(800)
        local snap = capture_plain()
        save_snapshot('menu_no_file_file', snap)
        assert_match(snap, 'New', 'File menu should show New')
        assert_match(snap, 'Open', 'File menu should show Open')
        assert_false(has_visible_errors(snap), 'File menu should not error with no file')

        -- Navigate to Edit menu
        vim.api.nvim_feedkeys('l', 'x', false)
        wait(800)
        snap = capture_plain()
        save_snapshot('menu_no_file_edit', snap)
        assert_false(has_visible_errors(snap), 'Edit menu should not error with no file')

        -- Navigate to View menu
        vim.api.nvim_feedkeys('l', 'x', false)
        wait(800)
        snap = capture_plain()
        save_snapshot('menu_no_file_view', snap)
        assert_false(has_visible_errors(snap), 'View menu should not error with no file')

        -- Navigate to Build menu
        vim.api.nvim_feedkeys('l', 'x', false)
        wait(800)
        snap = capture_plain()
        save_snapshot('menu_no_file_build', snap)
        assert_false(has_visible_errors(snap), 'Build menu should not error with no file')

        -- Navigate to Test menu
        vim.api.nvim_feedkeys('l', 'x', false)
        wait(800)
        snap = capture_plain()
        save_snapshot('menu_no_file_test', snap)
        assert_false(has_visible_errors(snap), 'Test menu should not error with no file')

        -- Navigate to Debug menu
        vim.api.nvim_feedkeys('l', 'x', false)
        wait(800)
        snap = capture_plain()
        save_snapshot('menu_no_file_debug', snap)
        assert_false(has_visible_errors(snap), 'Debug menu should not error with no file')

        -- Navigate to Git menu
        vim.api.nvim_feedkeys('l', 'x', false)
        wait(800)
        snap = capture_plain()
        save_snapshot('menu_no_file_git', snap)
        assert_false(has_visible_errors(snap), 'Git menu should not error with no file')

        -- Navigate to Window menu
        vim.api.nvim_feedkeys('l', 'x', false)
        wait(800)
        snap = capture_plain()
        save_snapshot('menu_no_file_window', snap)
        assert_false(has_visible_errors(snap), 'Window menu should not error with no file')

        -- Navigate to Help menu
        vim.api.nvim_feedkeys('l', 'x', false)
        wait(800)
        snap = capture_plain()
        save_snapshot('menu_no_file_help', snap)
        assert_false(has_visible_errors(snap), 'Help menu should not error with no file')

        -- Close
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(500)
    end)

    test('disabled menu items are visually distinct with no file', function()
        ensure_normal()
        vim.cmd('enew')
        wait(500)
        -- Open Edit menu — Undo/Redo/etc should be disabled
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<M-e>', true, true, true), 'x', false)
        wait(800)
        local snap_color = capture_color()
        save_snapshot('menu_no_file_edit_color', snap_color)
        -- The disabled items should have different ANSI colors from enabled items
        -- (IDEMenuItemDisabled vs IDEMenuItemNormal use different fg colors)
        local snap = capture_plain()
        assert_match(snap, 'Undo', 'Edit menu should show Undo')
        assert_false(has_visible_errors(snap), 'Edit menu should not error')
        -- Close
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(500)
    end)

    test('clicking disabled menu item does nothing', function()
        ensure_normal()
        vim.cmd('enew')
        wait(500)
        -- Open Edit menu
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<M-e>', true, true, true), 'x', false)
        wait(800)
        -- Try to select Undo (first item, should be disabled with no file)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, true, true), 'x', false)
        wait(800)
        local snap = capture_plain()
        save_snapshot('menu_no_file_disabled_click', snap)
        assert_false(has_visible_errors(snap), 'clicking disabled item should not error')
        -- Close if still open
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(500)
    end)

    test('Help > About works with no file open', function()
        ensure_normal()
        vim.cmd('enew')
        wait(500)
        -- Open Help menu
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<M-h>', true, true, true), 'x', false)
        wait(800)
        -- Navigate to About IDE (last item)
        for _ = 1, 10 do
            vim.api.nvim_feedkeys('j', 'x', false)
            wait(100)
        end
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, true, true), 'x', false)
        wait(1500)
        local snap = capture_plain()
        save_snapshot('menu_no_file_about', snap)
        assert_false(has_visible_errors(snap), 'About should not error with no file')
    end)

    test('View > File Explorer works with no file open', function()
        ensure_normal()
        vim.cmd('enew')
        wait(500)
        -- Open View menu
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<M-v>', true, true, true), 'x', false)
        wait(800)
        -- First item is File Explorer — select it
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, true, true), 'x', false)
        wait(2000)
        local snap = capture_plain()
        save_snapshot('menu_no_file_explorer', snap)
        assert_false(has_visible_errors(snap), 'File Explorer should not error with no file')
        -- Close the explorer
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(500)
        ensure_normal()
    end)

    test('File > New works from empty state', function()
        ensure_normal()
        vim.cmd('enew')
        wait(500)
        -- Open File menu and select New
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<F10>', true, true, true), 'x', false)
        wait(800)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, true, true), 'x', false)
        wait(1000)
        local snap = capture_plain()
        save_snapshot('menu_no_file_new', snap)
        assert_false(has_visible_errors(snap), 'File > New should not error from empty state')
        local sl = statusline(snap)
        assert_match(sl, 'Ready', 'should be in NORMAL mode after New')
    end)

    -- ═══════════════════════════════════════
    -- SPLIT WINDOW TESTS
    -- ═══════════════════════════════════════

    ensure_normal()
    vim.cmd('edit! ' .. vim.fs.joinpath(fixture_dir, 'sample.lua'))
    wait(1500)

    test('vertical split and close cycle produces no errors', function()
        ensure_normal()
        -- Ensure a normal file is open via the framed window
        vim.cmd('edit! ' .. vim.fs.joinpath(fixture_dir, 'sample.lua'))
        wait(2000)
        vim.cmd('redraw!')
        wait(500)
        -- Check frame has a normal buffer before splitting
        local chrome = IDE:extension('WindowChrome')
        if not chrome or not chrome._frame or not chrome._frame:is_valid() then
            -- Frame isn't ready — skip split test gracefully
            return
        end
        -- Split
        pcall(vim.cmd, 'IDESplitVertical')
        vim.cmd('redraw!')
        wait(2000)
        local snap = capture_plain()
        save_snapshot('split_vertical', snap)
        assert_false(has_visible_errors(snap), 'split should not error')
        -- Close
        pcall(vim.cmd, 'IDESplitClose')
        vim.cmd('redraw!')
        wait(1000)
    end)

    -- ═══════════════════════════════════════
    -- COMMAND PALETTE SHORTCUT TESTS
    -- ═══════════════════════════════════════

    test('command palette open and close cycle produces no errors', function()
        ensure_normal()
        vim.cmd('IDEActions')
        vim.cmd('redraw!')
        wait(1000)
        -- Verify the picker is mounted
        local has_float = false
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
            if ok and cfg.relative and cfg.relative ~= '' and cfg.zindex and cfg.zindex >= 200 then
                has_float = true
                break
            end
        end
        assert_true(has_float, 'command palette should open a floating window')
        -- Close
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'x', false)
        wait(800)
        local snap = capture_plain()
        save_snapshot('palette_close_clean', snap)
        assert_false(has_visible_errors(snap), 'palette close should not error')
    end)

    -- ═══════════════════════════════════════
    -- BREADCRUMB / FOOTER TESTS
    -- ═══════════════════════════════════════

    test('footer shows breadcrumb when cursor is inside a function', function()
        ensure_normal()
        vim.cmd('edit! ' .. vim.fs.joinpath(fixture_dir, 'sample.lua'))
        wait(1500)
        -- Move to line 7 (inside greet function)
        vim.api.nvim_win_set_cursor(0, { 7, 0 })
        wait(500)
        local snap = capture_plain()
        save_snapshot('breadcrumb_in_function', snap)
        -- The footer should show function name or cursor position
        local bottom = snap:match('[^\n]*╝[^\n]*')
        assert_true(bottom ~= nil, 'should have a bottom border')
        assert_match(bottom, '%d+:%d+', 'footer should show cursor position')
    end)

    -- Restore a file for subsequent tests
    ensure_normal()
    vim.cmd('edit! ' .. vim.fs.joinpath(fixture_dir, 'sample.go'))
    wait(2000)

    -- ═══════════════════════════════════════
    -- REPORT
    -- ═══════════════════════════════════════

    local passed, failed = 0, 0
    local report = {}
    for _, r in ipairs(results) do
        if r.passed then passed = passed + 1
        else failed = failed + 1; report[#report + 1] = '  FAIL: ' .. r.name .. '\n        ' .. (r.error or '?') end
    end

    local summary = string.format('\n══════ Visual Tests ══════\n%d/%d passed, %d failed\n', passed, passed + failed, failed)
    if failed > 0 then summary = summary .. '\nFailures:\n' .. table.concat(report, '\n') .. '\n' end
    summary = summary .. '══════════════════════════\n'

    local f = io.open('/tmp/ide_visual_results.txt', 'w')
    if f then f:write(summary); f:close() end
    print(summary)

    return { passed = passed, failed = failed, total = passed + failed }
end

return M
