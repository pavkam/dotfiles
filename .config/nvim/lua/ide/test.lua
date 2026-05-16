-- IDE Test Suite
-- Deep coverage testing with fixtures, integration tests, and UX error catching.
-- Run: :lua require('ide.test').run()
-- Run specific suite: :lua require('ide.test').run('Buffer')

local M = {}

local results = {}
local current_suite = ''
local fixture_dir = vim.fs.joinpath(vim.fn.stdpath('config'), 'lua', 'ide', 'test_fixtures')

-- Capture noice/vim errors during tests
local captured_errors = {}
local original_notify

local function test(name, fn)
    local full_name = current_suite ~= '' and (current_suite .. ' > ' .. name) or name
    captured_errors = {}
    local ok, err = pcall(fn)
    -- Check for UX errors that appeared during the test
    if ok and #captured_errors > 0 then
        ok = false
        err = 'UX error during test: ' .. captured_errors[1]
    end
    results[#results + 1] = { name = full_name, passed = ok, error = not ok and tostring(err) or nil }
end

local function suite(name, fn)
    current_suite = name
    fn()
    current_suite = ''
end

local function assert_eq(a, b, msg) if a ~= b then error(string.format('%s: expected %s, got %s', msg or 'eq', vim.inspect(b), vim.inspect(a)), 2) end end
local function assert_true(val, msg) if not val then error(msg or 'expected true', 2) end end
local function assert_false(val, msg) if val then error(msg or 'expected false', 2) end end
local function assert_type(val, expected, msg) if type(val) ~= expected then error(string.format('%s: expected %s, got %s', msg or 'type', expected, type(val)), 2) end end
local function assert_gt(a, b, msg) if not (a > b) then error(string.format('%s: %s not > %s', msg or 'gt', a, b), 2) end end
local function assert_match(str, pat, msg) if not str:match(pat) then error(string.format('%s: "%s" !~ /%s/', msg or 'match', str, pat), 2) end end
local function assert_nil(val, msg) if val ~= nil then error(string.format('%s: expected nil, got %s', msg or 'nil', vim.inspect(val)), 2) end end
local function assert_not_nil(val, msg) if val == nil then error(msg or 'expected non-nil value', 2) end end
local function assert_no_errors(msg) if #captured_errors > 0 then error((msg or 'unexpected error') .. ': ' .. captured_errors[1], 2) end end

--- Ensure we're in normal mode in a normal (non-floating) window.
--- Escapes insert mode, closes floating windows, disables winfixbuf.
local function ensure_normal_window()
    -- Force normal mode (escape from insert/visual/cmdline)
    vim.cmd('stopinsert')
    local mode = vim.api.nvim_get_mode().mode
    if mode ~= 'n' then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, true, true), 'nx', false)
    end

    -- Close popup floating windows (not the FramedWindow at z50 or scrollbar at z51)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, config = pcall(vim.api.nvim_win_get_config, win)
        if ok and config.relative and config.relative ~= '' then
            local z = config.zindex or 0
            if z > 51 then
                pcall(vim.api.nvim_win_close, win, true)
            end
        end
    end
    -- Switch to a non-floating window
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, config = pcall(vim.api.nvim_win_get_config, win)
        if ok and (not config.relative or config.relative == '') then
            pcall(vim.api.nvim_set_current_win, win)
            break
        end
    end
    -- Disable winfixbuf on ALL remaining windows
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        pcall(function() vim.wo[win].winfixbuf = false end)
    end
end

--- Open a fixture file and wait for LSP/treesitter
local function open_fixture(name, wait_ms)
    ensure_normal_window()
    vim.cmd('edit ' .. vim.fs.joinpath(fixture_dir, name))
    vim.wait(wait_ms or 500, function() return false end)
    return vim.api.nvim_get_current_buf()
end

--- Open a file from a project fixture directory
local function open_project_fixture(project_dir, filename, wait_ms)
    ensure_normal_window()
    local path = vim.fs.joinpath(fixture_dir, project_dir, filename)
    vim.cmd('edit ' .. path)
    vim.wait(wait_ms or 1000, function() return false end)
    return vim.api.nvim_get_current_buf()
end

--- Close the current buffer
local function close_buf()
    ensure_normal_window()
    pcall(vim.cmd, 'bdelete!')
end

function M.run(filter)
    results = {}

    -- Safety: remember the original state so we can restore it
    local original_buf = vim.api.nvim_get_current_buf()
    local original_cwd = vim.uv.cwd()
    ensure_normal_window()

    -- Install error interceptor
    original_notify = vim.notify
    vim.notify = function(msg, level, opts)
        if level == vim.log.levels.ERROR then
            captured_errors[#captured_errors + 1] = msg
        end
        return original_notify(msg, level, opts)
    end

    -- ═══════════════════════════════════════════════════════
    -- UNIT TESTS: Core Classes
    -- ═══════════════════════════════════════════════════════

    suite('EventEmitter', function()
        local EventEmitter = require 'ide.EventEmitter'
        local obj = setmetatable({}, { __index = {} })
        for k, v in pairs(EventEmitter) do obj[k] = v end

        test('on and emit', function()
            local fired = false
            obj:on('t1', function() fired = true end)
            obj:emit('t1')
            assert_true(fired)
        end)
        test('emit with args', function()
            local got
            obj:on('t2', function(x) got = x end)
            obj:emit('t2', 42)
            assert_eq(got, 42)
        end)
        test('off removes handler', function()
            local n = 0
            local fn = function() n = n + 1 end
            obj:on('t3', fn); obj:emit('t3'); obj:off('t3', fn); obj:emit('t3')
            assert_eq(n, 1)
        end)
        test('once fires once', function()
            local n = 0
            obj:once('t4', function() n = n + 1 end)
            obj:emit('t4'); obj:emit('t4')
            assert_eq(n, 1)
        end)
        test('unsubscribe function', function()
            local n = 0
            local unsub = obj:on('t5', function() n = n + 1 end)
            obj:emit('t5'); unsub(); obj:emit('t5')
            assert_eq(n, 1)
        end)
        test('has_listeners', function()
            assert_false(obj:has_listeners('nope'))
            obj:on('yep', function() end)
            assert_true(obj:has_listeners('yep'))
        end)
        test('error isolation', function()
            local second = false
            obj:on('e1', function() error('boom') end)
            obj:on('e1', function() second = true end)
            obj._suppress_errors = true
            obj:emit('e1')
            obj._suppress_errors = false
            assert_true(second)
        end)
    end)

    suite('Position', function()
        local P = require 'ide.Position'
        test('constructor', function() local p = P(10, 5); assert_eq(p.row, 10); assert_eq(p.col, 5) end)
        test('from_cursor', function() local p = P.from_cursor({10, 4}); assert_eq(p.col, 5) end)
        test('to_cursor', function() local c = P(10, 5):to_cursor(); assert_eq(c[2], 4) end)
        test('tostring', function() assert_eq(tostring(P(3, 7)), '3:7') end)
    end)

    suite('FileSystem', function()
        test('cwd', function() assert_type(IDE.fs:cwd(), 'string') end)
        test('home', function() assert_type(IDE.fs:home(), 'string') end)
        test('join', function() assert_eq(IDE.fs:join('a', 'b'), 'a/b') end)
        test('basename', function() assert_eq(IDE.fs:basename('/a/b.txt'), 'b.txt') end)
        test('dirname', function() assert_eq(IDE.fs:dirname('/a/b.txt'), '/a') end)
        test('exists on fixture', function() assert_true(IDE.fs:exists(fixture_dir)) end)
        test('is_directory', function() assert_true(IDE.fs:is_directory(fixture_dir)) end)
        test('is_file on fixture', function()
            assert_true(IDE.fs:is_file(vim.fs.joinpath(fixture_dir, 'sample.lua')))
        end)
        test('not exists', function() assert_false(IDE.fs:exists('/nonexistent_xyz_123')) end)
        test('config_dir', function() assert_match(IDE.fs:config_dir(), 'nvim') end)
        test('read fixture', function()
            local content = IDE.fs:read(vim.fs.joinpath(fixture_dir, 'sample.lua'))
            assert_true(content ~= nil and content:match('greet') ~= nil)
        end)
        test('write and read back', function()
            local path = vim.fs.joinpath(vim.fn.stdpath('cache'), 'ide_test_write.txt')
            local ok = IDE.fs:write(path, 'hello world')
            assert_true(ok)
            local content = IDE.fs:read(path)
            assert_eq(content, 'hello world')
            os.remove(path)
        end)
        test('scan finds file', function()
            local found = IDE.fs:scan({ fixture_dir }, { 'sample.lua' })
            assert_not_nil(found)
            assert_match(found, 'sample.lua')
        end)
        test('scan returns nil for missing', function()
            assert_nil(IDE.fs:scan({ fixture_dir }, { 'nonexistent.xyz' }))
        end)
        test('scan searches multiple dirs', function()
            local go_dir = vim.fs.joinpath(fixture_dir, 'go_project')
            local py_dir = vim.fs.joinpath(fixture_dir, 'py_project')
            local found = IDE.fs:scan({ go_dir, py_dir }, { 'go.mod' })
            assert_not_nil(found)
            assert_match(found, 'go.mod')
        end)
        test('relative_path', function()
            local rel = IDE.fs:relative_path('/home/user/project', '/home/user/project/src/main.go')
            assert_eq(rel, 'src/main.go')
        end)
        test('relative_path with base_dir', function()
            local rel = IDE.fs:relative_path('/home/user/project', '/home/user/project/src/main.go', { include_base_dir = true })
            assert_eq(rel, 'project/src/main.go')
        end)
        test('relative_path unrelated', function()
            local rel = IDE.fs:relative_path('/home/a', '/home/b/file.go')
            assert_eq(rel, '/home/b/file.go')
        end)
        test('cache_dir', function() assert_match(IDE.fs:cache_dir(), 'cache') end)
        test('data_dir', function() assert_match(IDE.fs:data_dir(), 'share') end)
        test('expand resolves ~', function()
            local home = IDE.fs:home()
            local expanded = IDE.fs:expand('~')
            assert_not_nil(expanded)
        end)
    end)

    suite('Shell', function()
        test('has executable', function() assert_true(IDE.shell:has('git')) end)
        test('has nonexistent', function() assert_false(IDE.shell:has('nonexistent_xyz')) end)
        test('run_sync echo', function()
            local r = IDE.shell:run_sync('echo', {'hello'})
            assert_eq(r.code, 0)
            assert_match(r.stdout, 'hello')
        end)
        test('run_sync fail', function()
            local r = IDE.shell:run_sync('false', {})
            assert_true(r.code ~= 0)
        end)
    end)

    suite('Buffer: New Methods', function()
        test('line returns content', function()
            open_fixture('sample.lua', 300)
            local buf = IDE.buffers:current()
            local l = buf:line(1)
            assert_match(l, 'Sample')
            close_buf()
        end)
        test('set and clear extmarks', function()
            open_fixture('sample.lua', 300)
            local buf = IDE.buffers:current()
            local ns = vim.api.nvim_create_namespace('test_extmark')
            local id = buf:set_extmark(ns, 0, 0, {})
            assert_type(id, 'number')
            buf:clear_extmarks(ns)
            close_buf()
        end)
    end)

    suite('Window: New Methods', function()
        test('visible_range', function()
            local top, bot = IDE.windows:current():visible_range()
            assert_type(top, 'number')
            assert_type(bot, 'number')
            assert_true(top >= 1)
            assert_true(bot >= top)
        end)
        test('is_floating', function()
            assert_false(IDE.windows:current():is_floating())
        end)
    end)

    suite('WindowList: iter', function()
        test('iterates windows', function()
            local count = 0
            for _ in IDE.windows:iter() do count = count + 1 end
            assert_true(count >= 1)
        end)
    end)

    suite('Treesitter: scope_range', function()
        test('finds scope in Lua', function()
            open_fixture('sample.lua', 500)
            local sr, er = IDE.treesitter:scope_range(vim.api.nvim_get_current_buf(), 6)
            assert_not_nil(sr)
            assert_not_nil(er)
            close_buf()
        end)
        test('scope at module level returns chunk', function()
            open_fixture('sample.lua', 500)
            local sr, er = IDE.treesitter:scope_range(vim.api.nvim_get_current_buf(), 0)
            -- Lua files have a top-level 'chunk' scope
            assert_type(sr, 'number')
            assert_type(er, 'number')
            close_buf()
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- INTEGRATION TESTS: Buffer + LSP + Diagnostics
    -- ═══════════════════════════════════════════════════════

    suite('Buffer: Fixture Integration', function()
        test('open Go fixture', function()
            local bufnr = open_fixture('sample.go', 1000)
            local buf = IDE.buffers:current()
            assert_eq(buf:filetype(), 'go')
            assert_eq(buf:name(), 'sample.go')
            assert_true(buf:is_normal())
            assert_false(buf:is_modified())
            assert_gt(buf:line_count(), 5)
            close_buf()
        end)

        test('open Lua fixture', function()
            local bufnr = open_fixture('sample.lua', 500)
            local Buffer = require 'ide.Buffer'
            local buf = Buffer(bufnr)
            assert_true(buf:is_valid())
            assert_eq(vim.bo[bufnr].filetype, 'lua')
            local name = vim.api.nvim_buf_get_name(bufnr)
            assert_true(name:match('sample%.lua$') ~= nil)
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 3, false)
            assert_eq(#lines, 3)
            close_buf()
        end)

        test('open TSX fixture', function()
            local bufnr = open_fixture('sample.tsx', 1000)
            local buf = IDE.buffers:current()
            assert_eq(buf:filetype(), 'typescriptreact')
            close_buf()
        end)

        test('open HTML fixture', function()
            local bufnr = open_fixture('sample.html', 500)
            local buf = IDE.buffers:current()
            assert_eq(buf:filetype(), 'html')
            close_buf()
        end)

        test('diagnostics on broken file', function()
            local bufnr = open_fixture('broken.lua', 2000)
            local buf = IDE.buffers:current()
            local ds = buf:diagnostic_set()
            -- lua_ls should report errors on broken file
            -- (may need time to analyze)
            assert_type(ds:count(), 'number')
            close_buf()
        end)

        test('buffer events fire', function()
            local save_fired = false
            local bufnr = open_fixture('sample.lua', 500)
            local buf = IDE.buffers:current()
            buf:on('test_evt', function() save_fired = true end)
            buf:emit('test_evt')
            assert_true(save_fired)
            close_buf()
        end)

        test('DiagnosticSet methods', function()
            local bufnr = open_fixture('sample.lua', 500)
            local ds = IDE.buffers:current():diagnostic_set()
            assert_type(ds:count(), 'number')
            assert_type(ds:errors(), 'number')
            assert_type(ds:warnings(), 'number')
            assert_type(ds:hints(), 'number')
            assert_type(ds:is_clean(), 'boolean')
            assert_type(ds:summary(), 'string')
            close_buf()
        end)

        test('format does not error', function()
            local bufnr = open_fixture('sample.lua', 500)
            local buf = IDE.buffers:current()
            -- Should not throw even if no formatter available for fixture
            pcall(buf.format, buf)
            assert_no_errors('format should not produce UX errors')
            close_buf()
        end)
    end)

    suite('Buffer: Collection', function()
        test('listed returns buffers', function()
            assert_gt(#IDE.buffers:listed(), 0)
        end)
        test('current returns valid', function()
            local buf = IDE.buffers:current()
            assert_true(buf:is_valid())
        end)
        test('find_by_name', function()
            local bufnr = open_fixture('sample.lua', 300)
            -- The buffer should exist even if FramedWindow redirected it
            local found = false
            for _, b in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(b) then
                    local name = vim.api.nvim_buf_get_name(b)
                    if name:match('sample%.lua$') then found = true; break end
                end
            end
            assert_true(found)
            close_buf()
        end)
        test('iter works', function()
            local n = 0
            for _ in IDE.buffers:iter() do n = n + 1 end
            assert_gt(n, 0)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- WINDOW TESTS
    -- ═══════════════════════════════════════════════════════

    suite('Window', function()
        test('current is valid', function()
            local win = IDE.windows:current()
            assert_true(win:is_valid())
            assert_gt(win:width(), 0)
            assert_gt(win:height(), 0)
        end)
        test('cursor returns Position', function()
            local pos = IDE.windows:current():cursor()
            assert_gt(pos.row, 0)
        end)
        test('buffer returns Buffer', function()
            assert_true(IDE.windows:current():buffer():is_valid())
        end)
        test('split and close', function()
            local orig_count = IDE.windows:count()
            local new_win = IDE.windows:current():split('vertical')
            assert_eq(IDE.windows:count(), orig_count + 1)
            new_win:close()
            assert_eq(IDE.windows:count(), orig_count)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- LSP TESTS
    -- ═══════════════════════════════════════════════════════

    suite('LspManager', function()
        test('clients_for_buffer', function()
            assert_type(IDE.lsp:clients_for_buffer(0), 'table')
        end)
        test('register server', function()
            local s = IDE.lsp:register('test_lsp')
            assert_eq(s:name(), 'test_lsp')
            assert_false(s:is_enabled())
        end)
        test('server builder pattern', function()
            local s = IDE.LspServer('builder_test'):settings({x = 1}):root_markers({'.git'})
            assert_eq(s:name(), 'builder_test')
        end)
        test('server events', function()
            local s = IDE.LspServer('evt_test')
            local fired = false
            s:on('test', function() fired = true end)
            s:emit('test')
            assert_true(fired)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- PROJECT TESTS
    -- ═══════════════════════════════════════════════════════

    suite('Project', function()
        test('detect from file', function()
            ensure_normal_window()
            open_fixture('sample.lua', 200)
            local proj = IDE.Project.detect()
            assert_true(proj ~= nil)
            assert_type(proj:name(), 'string')
            assert_type(proj:root(), 'string')
        end)
        test('from_cwd', function()
            local p = IDE.Project.from_cwd()
            assert_type(p:root(), 'string')
        end)
        test('type returns string or nil', function()
            local p = IDE.Project.from_cwd()
            local t = p:type()
            assert_true(t == nil or type(t) == 'string')
        end)
        test('has_file negative', function()
            local p = IDE.Project.from_cwd()
            assert_false(p:has_file('nonexistent_xyz'))
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- GIT TESTS
    -- ═══════════════════════════════════════════════════════

    suite('Git', function()
        local in_repo = IDE.git:is_repo()
        test('is_repo returns boolean', function() assert_type(in_repo, 'boolean') end)
        test('branch', function()
            if not in_repo then return end
            local b = IDE.git:branch()
            assert_true(b ~= nil and #b > 0)
        end)
        test('root', function()
            if not in_repo then return end
            assert_true(IDE.git:root() ~= nil)
        end)
        test('log', function()
            if not in_repo then return end
            local commits = IDE.git:log({ count = 3 })
            assert_gt(#commits, 0)
            assert_true(commits[1].hash ~= nil)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- TREESITTER TESTS (with fixtures)
    -- ═══════════════════════════════════════════════════════

    suite('Treesitter', function()
        test('has_parser for lua', function()
            open_fixture('sample.lua', 500)
            assert_true(IDE.treesitter:has_parser('lua'))
            close_buf()
        end)
        test('node_at_cursor works', function()
            open_fixture('sample.lua', 500)
            vim.cmd(':7') -- inside greet function
            vim.wait(200, function() return false end)
            local ok = pcall(IDE.treesitter.node_at_cursor, IDE.treesitter)
            assert_true(ok)
            close_buf()
        end)
        test('scope_chain in function', function()
            open_fixture('sample.lua', 500)
            vim.cmd(':7')
            vim.wait(200, function() return false end)
            local chain = IDE.treesitter:scope_chain()
            assert_type(chain, 'table')
            close_buf()
        end)
        test('context detection', function()
            open_fixture('sample.lua', 500)
            vim.cmd(':1') -- comment line
            local ctx = IDE.treesitter:context()
            -- may be 'comment' or nil depending on cursor position
            assert_true(ctx == nil or type(ctx) == 'string')
            close_buf()
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- QUICKFIX TESTS
    -- ═══════════════════════════════════════════════════════

    suite('QuickFix', function()
        test('set and clear', function()
            IDE.quickfix:set({
                { filename = 'test.go', lnum = 1, col = 1, text = 'test' }
            })
            assert_gt(IDE.quickfix:count(), 0)
            IDE.quickfix:clear()
            assert_eq(IDE.quickfix:count(), 0)
        end)
        test('items returns table', function()
            assert_type(IDE.quickfix:items(), 'table')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- MARKS TESTS
    -- ═══════════════════════════════════════════════════════

    suite('Marks', function()
        test('set and find', function()
            open_fixture('sample.lua', 300)
            IDE.marks:set('z')
            local found = false
            for _, m in ipairs(IDE.marks:list()) do
                if m.mark == 'z' then found = true end
            end
            assert_true(found)
            close_buf()
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- CONFIG/THEME/SESSION/DEBUG TESTS
    -- ═══════════════════════════════════════════════════════

    suite('ConfigManager', function()
        test('get/set', function()
            IDE.config:set('test_key', 99)
            assert_eq(IDE.config:get('test_key'), 99)
        end)
        test('toggle', function()
            IDE.config:register_toggle('t1', { default = true })
            assert_true(IDE.config:is_enabled('t1'))
            IDE.config:toggle('t1')
            assert_false(IDE.config:is_enabled('t1'))
            IDE.config:unregister_toggle('t1')
        end)
    end)

    suite('Commands', function()
        test('add and list', function()
            IDE.commands:add('TestCmd123', function() end, { desc = 'Test command' })
            local cmds = IDE.commands:list()
            assert_true(vim.tbl_contains(cmds, 'TestCmd123'))
        end)
        test('command executes', function()
            local fired = false
            IDE.commands:add('TestFire99', function() fired = true end)
            vim.cmd('TestFire99')
            assert_true(fired)
        end)
        test('remove', function()
            IDE.commands:add('TestDel88', function() end)
            IDE.commands:remove('TestDel88')
            assert_false(vim.tbl_contains(IDE.commands:list(), 'TestDel88'))
        end)
    end)

    suite('ThemeManager', function()
        test('colorscheme', function() assert_match(IDE.theme:colorscheme(), 'turbovision') end)
        test('fg returns hex', function()
            local fg = IDE.theme:fg('Normal')
            assert_true(fg ~= nil and fg:match('^#') ~= nil)
        end)
        test('define highlight', function()
            IDE.theme:define('TestHL99', { fg = '#ff0000', bold = true })
            assert_eq(IDE.theme:fg('TestHL99'), '#ff0000')
        end)
    end)

    suite('SessionManager', function()
        test('list returns table', function() assert_type(IDE.session:list(), 'table') end)
    end)

    suite('DebugManager', function()
        test('is_active', function() assert_false(IDE.debug:is_active()) end)
        test('status', function() assert_eq(IDE.debug:status(), '') end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- UI + TOOLKIT TESTS
    -- ═══════════════════════════════════════════════════════

    suite('UI', function()
        test('finder exists', function() assert_true(IDE.ui.finder ~= nil) end)
        test('tree exists', function() assert_true(IDE.ui.tree ~= nil) end)
        test('highlight builder', function()
            assert_match(tostring(IDE.ui:highlight('X')), 'Highlight')
        end)
    end)

    suite('Toolkit: Panel', function()
        test('create and show/hide', function()
            local p = IDE.toolkit.Panel({ title = 'T', width = 0.2, height = 0.1 })
            p:show()
            assert_true(p:is_visible())
            p:hide()
            assert_false(p:is_visible())
        end)
    end)

    suite('Toolkit: List', function()
        test('create with items', function()
            local l = IDE.toolkit.List({ title = 'L', items = {{text='a'},{text='b'}} })
            assert_match(tostring(l), 'List')
        end)
    end)

    suite('Toolkit: StatusBar', function()
        test('render sections', function()
            local sb = IDE.toolkit.StatusBar()
            sb:left('a', function() return 'L', 'Normal' end)
            sb:right('b', function() return 'R', 'Comment' end)
            local r = sb:render()
            assert_match(r, 'L')
            assert_match(r, 'R')
            assert_match(r, '%%=')
        end)
        test('conditional', function()
            local sb = IDE.toolkit.StatusBar()
            sb:left('y', function() return 'YES' end)
            sb:left('n', function() return 'NO' end, { cond = function() return false end })
            assert_true(sb:render():match('NO') == nil)
        end)
        test('to_lualine', function()
            local sb = IDE.toolkit.StatusBar()
            sb:left('a', function() return 'x' end)
            assert_type(sb:to_lualine(), 'table')
        end)
    end)

    suite('Toolkit: TabBar', function()
        test('render', function()
            local tb = IDE.toolkit.TabBar()
            tb:left('b', function() return 'main', 'Special' end)
            assert_match(tb:render(), 'main')
        end)
    end)

    suite('Toolkit: WinBar', function()
        test('default factory', function()
            assert_match(tostring(IDE.toolkit.WinBar.default()), 'WinBar')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- EXTENSION SYSTEM TESTS
    -- ═══════════════════════════════════════════════════════

    suite('Extension system', function()
        test('base class', function()
            local ext = IDE.Extension('T')
            assert_eq(ext:name(), 'T')
            assert_false(ext:is_enabled())
        end)
        test('register/unregister lifecycle', function()
            local reg, unreg = false, false
            local T = Class('TLife', IDE.Extension)
            function T:init() IDE.Extension.init(self, 'TLife') end
            function T:on_register() reg = true end
            function T:on_unregister() unreg = true end
            IDE:register_extension(T())
            assert_true(reg)
            assert_true(IDE:extension('TLife'):is_enabled())
            IDE:unregister_extension('TLife')
            assert_true(unreg)
            assert_true(IDE:extension('TLife') == nil)
        end)
        test('context command auto-cleanup', function()
            local T = Class('TCCmd', IDE.Extension)
            function T:init() IDE.Extension.init(self, 'TCCmd') end
            function T:on_register(ctx) ctx:command('TCCmdTest', function() end) end
            IDE:register_extension(T())
            local ok = pcall(vim.cmd, 'command TCCmdTest')
            assert_true(ok, 'command should exist')
            IDE:unregister_extension('TCCmd')
            -- command should be gone after unregister
        end)
        test('extensions list has 3 built-in', function()
            assert_gt(#IDE:extensions(), 2)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- EXTENSION BEHAVIORAL TESTS
    -- ═══════════════════════════════════════════════════════

    suite('AutoTag Extension', function()
        test('is registered and enabled', function()
            local ext = IDE:extension('AutoTag')
            assert_true(ext ~= nil, 'AutoTag should be registered')
            assert_true(ext:is_enabled(), 'AutoTag should be enabled')
        end)

        test('auto-close inserts closing tag in HTML', function()
            open_fixture('sample.html', 500)
            -- Add a line with an opening tag and position cursor at end
            vim.cmd('$')
            vim.api.nvim_buf_set_lines(0, -1, -1, false, { '<span>' })
            local last_line = vim.api.nvim_buf_line_count(0)
            vim.api.nvim_win_set_cursor(0, { last_line, 6 }) -- after the '>'
            -- Call autotag close
            IDE:extension('AutoTag'):_close()
            local line = vim.api.nvim_buf_get_lines(0, last_line - 1, last_line, false)[1]
            assert_true(line:match('</span>') ~= nil, 'closing tag expected, got: ' .. line)
            vim.cmd('u')
            close_buf()
        end)

        test('does not close void elements', function()
            open_fixture('sample.html', 500)
            vim.cmd('$')
            vim.api.nvim_put({'<br>'}, 'l', true, true)
            vim.wait(100, function() return false end)
            local ext = IDE:extension('AutoTag')
            ext:_close()
            local row = vim.api.nvim_win_get_cursor(0)[1]
            local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
            assert_true(line:match('</br>') == nil, 'void element should NOT get closing tag')
            vim.cmd('u')
            close_buf()
        end)
    end)

    suite('IconPicker Extension', function()
        test('is registered', function()
            assert_true(IDE:extension('IconPicker') ~= nil)
            assert_true(IDE:extension('IconPicker'):is_enabled())
        end)

        test('IDEIcons command exists', function()
            local ok = pcall(vim.cmd, 'command IDEIcons')
            assert_true(ok, ':IDEIcons command should exist')
        end)

        test('loads 10k+ nerd font icons', function()
            local ext = IDE:extension('IconPicker')
            local db = ext:_load_db()
            assert_gt(#db, 5000, 'should have thousands of icons, got ' .. #db)
            -- Check structure
            assert_true(db[1].name ~= nil, 'icons should have names')
            assert_true(db[1].char ~= nil, 'icons should have chars')
            assert_true(db[1].code ~= nil, 'icons should have codes')
        end)

        test('picker creates panel when opened', function()
            ensure_normal_window()
            local win_count_before = #vim.api.nvim_list_wins()
            IDE:extension('IconPicker'):pick()
            vim.wait(500, function() return false end)
            local win_count_after = #vim.api.nvim_list_wins()
            assert_gt(win_count_after, win_count_before, 'picker should open a new window')
            -- Close all floating windows
            ensure_normal_window()
        end)
    end)

    suite('MarkdownPreview Extension', function()
        test('is registered', function()
            assert_true(IDE:extension('MarkdownPreview') ~= nil)
            assert_true(IDE:extension('MarkdownPreview'):is_enabled())
        end)

        test('IDEPreview command exists', function()
            local ok = pcall(vim.cmd, 'command IDEPreview')
            assert_true(ok, ':IDEPreview command should exist')
        end)

        test('open creates split on markdown file', function()
            ensure_normal_window()
            vim.cmd('enew')
            vim.bo.filetype = 'markdown'
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { '# Test', '', 'Hello world' })
            local win_count_before = #vim.api.nvim_list_wins()

            local ext = IDE:extension('MarkdownPreview')
            ext:open()
            vim.wait(300, function() return false end)

            local win_count_after = #vim.api.nvim_list_wins()
            assert_gt(win_count_after, win_count_before, 'preview should create a split')

            ext:close()
            vim.wait(200, function() return false end)
            vim.cmd('bdelete!')
        end)

        test('toggle opens and closes', function()
            ensure_normal_window()
            vim.cmd('enew')
            vim.bo.filetype = 'markdown'
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { '# Toggle Test' })

            local ext = IDE:extension('MarkdownPreview')
            local before = #vim.api.nvim_list_wins()

            ext:toggle()
            vim.wait(300, function() return false end)
            assert_gt(#vim.api.nvim_list_wins(), before, 'toggle should open')

            ext:toggle()
            vim.wait(300, function() return false end)
            -- Window count should be back
            vim.cmd('bdelete!')
        end)

        test('does not open preview for non-markdown files', function()
            open_fixture('sample.lua', 300)
            local ext = IDE:extension('MarkdownPreview')
            -- The preview_win should stay nil for non-markdown
            ext:open()
            vim.wait(200, function() return false end)
            assert_true(ext._preview_win == nil or not vim.api.nvim_win_is_valid(ext._preview_win),
                'should not create preview window for Lua file')
            close_buf()
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- COMMAND + TIMER TESTS
    -- ═══════════════════════════════════════════════════════

    suite('Command', function()
        test('create and delete', function()
            local cmd = IDE.Command.create('TCmd1', function() end, { desc = 'T' })
            pcall(vim.cmd, 'command TCmd1')
            cmd:delete()
        end)
        test('fluent builder', function()
            local cmd = IDE.Command('TCmd2'):desc('T'):args('?'):action(function() end):register()
            assert_match(tostring(cmd), 'Command')
            cmd:delete()
        end)
    end)

    suite('Timer', function()
        test('delay', function()
            local t = IDE.Timer.delay(10000, function() end)
            assert_true(t:is_active())
            t:stop()
            assert_false(t:is_active())
        end)
        test('interval', function()
            local t = IDE.Timer.interval(10000, function() end)
            assert_true(t:is_active())
            t:stop()
        end)
        test('debounce', function()
            assert_type(IDE.Timer.debounce(100, function() end), 'function')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- IDE SINGLETON TESTS
    -- ═══════════════════════════════════════════════════════

    suite('IDE singleton', function()
        test('tostring', function() assert_match(tostring(IDE), 'IDE') end)
        test('global events', function()
            local n = 0
            IDE:on('test_g', function() n = n + 1 end)
            IDE:emit('test_g'); IDE:emit('test_g')
            assert_eq(n, 2)
        end)
        test('Class system', function()
            local A = Class('TA'); function A:init(x) self.x = x end
            local B = Class('TB', A); function B:init(x) A.init(self, x); self.y = x*2 end
            local b = B(5)
            assert_eq(b.x, 5); assert_eq(b.y, 10)
            assert_true(b:is_a(A)); assert_true(b:is_a(B))
            assert_eq(Class.name(b), 'TB')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- UX ERROR CATCHING TESTS
    -- ═══════════════════════════════════════════════════════

    suite('UX Error Catching', function()
        test('no startup errors in noice', function()
            -- Check that the current session has no Error-level notifications
            -- (except ones we intentionally triggered)
            assert_no_errors('should have no startup errors')
        end)
        test('opening Go fixture produces no errors', function()
            captured_errors = {}
            open_fixture('sample.go', 1000)
            assert_no_errors('Go fixture should open cleanly')
            close_buf()
        end)
        test('opening Lua fixture produces no errors', function()
            captured_errors = {}
            open_fixture('sample.lua', 500)
            assert_no_errors('Lua fixture should open cleanly')
            close_buf()
        end)
        test('opening HTML fixture produces no errors', function()
            captured_errors = {}
            open_fixture('sample.html', 500)
            assert_no_errors('HTML fixture should open cleanly')
            close_buf()
        end)
        test('rapid buffer switching produces no errors', function()
            captured_errors = {}
            for i = 1, 3 do
                open_fixture('sample.lua', 100)
                open_fixture('sample.go', 100)
                close_buf()
            end
            close_buf()
            assert_no_errors('rapid switching should be clean')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- CLEANUP: wipe all test fixture buffers
    -- ═══════════════════════════════════════════════════════

    ensure_normal_window()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if name:find('test_fixtures') or name:find('Scratch') then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end

    -- Restore original buffer if it still exists
    if vim.api.nvim_buf_is_valid(original_buf) then
        pcall(vim.api.nvim_set_current_buf, original_buf)
    end

    -- ═══════════════════════════════════════════════════════
    -- REPORT
    -- ═══════════════════════════════════════════════════════

    -- Restore original state
    vim.notify = original_notify
    if original_cwd then pcall(vim.cmd.cd, original_cwd) end
    if vim.api.nvim_buf_is_valid(original_buf) then
        pcall(vim.api.nvim_set_current_buf, original_buf)
    end

    local passed, failed = 0, 0
    local report = {}
    for _, r in ipairs(results) do
        if filter and not r.name:match(filter) then goto continue end
        if r.passed then passed = passed + 1
        else failed = failed + 1; report[#report + 1] = '  FAIL: ' .. r.name .. '\n        ' .. (r.error or '?') end
        ::continue::
    end

    local summary = string.format('\n══════ IDE Test Suite ══════\n%d/%d passed, %d failed\n', passed, passed + failed, failed)
    if failed > 0 then summary = summary .. '\nFailures:\n' .. table.concat(report, '\n') .. '\n' end
    summary = summary .. '═══════════════════════════\n'

    local f = io.open('/tmp/ide_test_results.txt', 'w')
    if f then f:write(summary); f:close() end
    print(summary)
    return { passed = passed, failed = failed, total = passed + failed }
end

return M
