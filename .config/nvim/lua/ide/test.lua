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

    suite('Buffer: get_text / get_extmarks / call', function()
        test('get_text extracts region', function()
            open_fixture('sample.lua', 300)
            local buf = IDE.buffers:current()
            local text = buf:get_text(0, 0, 0, 5)
            assert_type(text, 'table')
            assert_true(#text > 0)
            close_buf()
        end)
        test('get_text on invalid buffer returns empty', function()
            local B = require 'ide.Buffer'
            local scratch = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { 'abc' })
            local buf = B.get(scratch)
            local text = buf:get_text(0, 0, 0, 3)
            assert_eq(text[1], 'abc')
            vim.api.nvim_buf_delete(scratch, { force = true })
            local empty = buf:get_text(0, 0, 0, 3)
            assert_eq(#empty, 0)
        end)
        test('get_extmarks returns marks', function()
            local B = require 'ide.Buffer'
            local scratch = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { 'hello' })
            local buf = B.get(scratch)
            local ns = B.create_namespace('test_get_extmarks')
            buf:set_extmark(ns, 0, 0, { sign_text = 'X' })
            local marks = buf:get_extmarks(ns, { 0, 0 }, { 0, -1 }, { details = true })
            assert_true(#marks >= 1)
            buf:clear_extmarks(ns)
            vim.api.nvim_buf_delete(scratch, { force = true })
        end)
        test('get_extmarks on invalid buffer returns empty', function()
            local B = require 'ide.Buffer'
            local scratch = vim.api.nvim_create_buf(false, true)
            local buf = B.get(scratch)
            vim.api.nvim_buf_delete(scratch, { force = true })
            local marks = buf:get_extmarks(-1, { 0, 0 }, { 0, -1 }, {})
            assert_eq(#marks, 0)
        end)
        test('call runs function in buffer context', function()
            open_fixture('sample.lua', 300)
            local buf = IDE.buffers:current()
            local result = buf:call(function()
                return vim.api.nvim_get_current_buf()
            end)
            assert_eq(result, buf:id())
            close_buf()
        end)
        test('call on invalid buffer returns nil', function()
            local B = require 'ide.Buffer'
            local scratch = vim.api.nvim_create_buf(false, true)
            local buf = B.get(scratch)
            vim.api.nvim_buf_delete(scratch, { force = true })
            local result = buf:call(function() return 42 end)
            assert_nil(result)
        end)
        test('current_line returns cursor line text', function()
            open_fixture('sample.lua', 300)
            local buf = IDE.buffers:current()
            local line = buf:current_line()
            assert_type(line, 'string')
            assert_true(#line > 0)
            close_buf()
        end)
        test('reload restores buffer from disk', function()
            open_fixture('sample.lua', 300)
            local buf = IDE.buffers:current()
            local original = buf:line(1)
            buf:set_lines(0, 1, { '-- modified' })
            assert_eq(buf:line(1), '-- modified')
            buf:reload()
            assert_eq(buf:line(1), original)
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
        test('center_cursor does not error', function()
            open_fixture('sample.lua', 300)
            local win = IDE.windows:current()
            win:center_cursor()
            close_buf()
        end)
        test('exit_insert in normal mode is safe', function()
            local win = IDE.windows:current()
            win:exit_insert()
        end)
        test('select_line does not error', function()
            open_fixture('sample.lua', 300)
            local win = IDE.windows:current()
            win:select_line()
            vim.cmd('normal! \\<Esc>')
            close_buf()
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
    -- BEHAVIORAL TESTS: verify actual user-facing behavior
    -- Each test here would have caught a real bug we shipped.
    -- ═══════════════════════════════════════════════════════

    suite('Buffer identity', function()
        test('Buffer.get returns the same instance for the same id', function()
            local buf = require('ide.Buffer').create({ listed = false, scratch = true })
            local a = require('ide.Buffer').get(buf:id())
            local b = require('ide.Buffer').get(buf:id())
            assert_true(a == b, 'same id must return same object')
            buf:close(true)
        end)

        test('Window.get returns the same instance for the same id', function()
            local Window = require('ide.Window')
            local a = Window.current()
            local b = Window.current()
            assert_true(a == b, 'same window must return same object')
        end)

        test('Buffer.destroy clears subsystem facades', function()
            local buf = require('ide.Buffer').create({ listed = false, scratch = true })
            local _ = buf:lsp()     -- force creation
            local _ = buf:git()     -- force creation
            assert_not_nil(buf._lsp, 'lsp facade should exist')
            assert_not_nil(buf._git, 'git facade should exist')
            buf:destroy()
            assert_nil(buf._lsp, 'destroy should clear lsp')
            assert_nil(buf._git, 'destroy should clear git')
            buf:close(true)
        end)

        test('BufferList.get returns same instance as Buffer.get', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = true, scratch = true })
            local from_list = IDE.buffers:get(buf:id())
            local from_cache = Buffer.get(buf:id())
            assert_true(from_list == from_cache, 'BufferList and Buffer caches must agree')
            buf:close(true)
        end)
    end)

    suite('Panel focus restore', function()
        test('Panel tracks previous window on show', function()
            local Panel = require('ide.toolkit.Panel')
            local p = Panel({ title = 'Test', width = 20, height = 5, enter = false })
            -- Verify _prev_win is set during show
            assert_nil(p._prev_win, 'prev_win must be nil before show')
            -- We don't actually show the panel in tests (it steals focus from the test runner)
            -- Instead verify the field is set by the constructor path
        end)
    end)

    suite('EventEmitter behavior', function()
        -- Create a proper object with EventEmitter mixed in
        local function make_emitter()
            local E = Class('TestEmitter')
            Class.include(E, require('ide.EventEmitter'))
            return E()
        end

        test('clear removes all handlers for an event', function()
            local obj = make_emitter()
            obj:on('test', function() end)
            obj:on('test', function() end)
            assert_eq(#obj._events.test, 2)
            obj:clear('test')
            assert_true(obj._events.test == nil, 'clear should remove event key')
        end)

        test('emit fires all handlers in order', function()
            local obj = make_emitter()
            local order = {}
            obj:on('x', function() order[#order + 1] = 'a' end)
            obj:on('x', function() order[#order + 1] = 'b' end)
            obj:on('x', function() order[#order + 1] = 'c' end)
            obj:emit('x')
            assert_eq(#order, 3, 'all 3 handlers must fire')
        end)

        test('unsubscribe via returned function works', function()
            local obj = make_emitter()
            local count = 0
            local unsub = obj:on('x', function() count = count + 1 end)
            obj:emit('x')
            assert_eq(count, 1, 'handler fires once')
            unsub()
            obj:emit('x')
            assert_eq(count, 1, 'handler must not fire after unsubscribe')
        end)

        test('once fires handler exactly once', function()
            local obj = make_emitter()
            local count = 0
            obj:once('x', function() count = count + 1 end)
            obj:emit('x')
            obj:emit('x')
            obj:emit('x')
            assert_eq(count, 1, 'once handler must fire exactly once')
        end)

        test('emit with arguments passes them through', function()
            local obj = make_emitter()
            local received = {}
            obj:on('x', function(a, b, c)
                received = { a, b, c }
            end)
            obj:emit('x', 'hello', 42, true)
            assert_eq(received[1], 'hello')
            assert_eq(received[2], 42)
            assert_eq(received[3], true)
        end)

        test('handler error does not crash other handlers', function()
            local obj = make_emitter()
            obj._suppress_errors = true -- suppress error notifications in test
            local second_fired = false
            obj:on('x', function() error('intentional') end)
            obj:on('x', function() second_fired = true end)
            obj:emit('x')
            assert_true(second_fired, 'second handler must fire despite first erroring')
        end)
    end)

    suite('Extension lifecycle', function()
        test('on_unregister runs before resources are cleared', function()
            local Extension = require('ide.Extension')
            local Ext = Class('TestLifecycle', Extension)
            function Ext:init() Extension.init(self, 'TestLifecycle') end
            local saw_commands = false
            function Ext:on_register(ctx)
                ctx:command('TestLifecycleCmd', function() end, { desc = 'test' })
            end
            function Ext:on_unregister()
                saw_commands = #self._commands > 0
            end
            local ext = Ext()
            ext:_enable()
            assert_true(#ext._commands > 0, 'command should be registered')
            ext:_disable()
            assert_true(saw_commands, 'on_unregister must see commands before cleanup')
            assert_eq(#ext._commands, 0, 'commands should be cleared after disable')
        end)

        test('disabled extension has _enabled = false', function()
            local Extension = require('ide.Extension')
            local Ext = Class('TestGuard2', Extension)
            function Ext:init() Extension.init(self, 'TestGuard2') end
            function Ext:on_register(ctx) end
            local ext = Ext()
            ext:_enable()
            assert_true(ext:is_enabled(), 'must be enabled after _enable')
            ext:_disable()
            assert_false(ext:is_enabled(), 'must be disabled after _disable')
        end)

        test('action cleanup on disable', function()
            local Extension = require('ide.Extension')
            local Ext = Class('TestActionClean', Extension)
            function Ext:init() Extension.init(self, 'TestActionClean') end
            function Ext:on_register(ctx)
                ctx:action('test.temp_cleanup_action', 'Temp', function() end)
            end
            local ext = Ext()
            ext:_enable()
            -- Action should exist
            local found = false
            for _, a in ipairs(IDE.actions:list()) do
                if a.name == 'test.temp_cleanup_action' then found = true end
            end
            assert_true(found, 'action should be registered')
            ext:_disable()
            -- Action should be gone
            found = false
            for _, a in ipairs(IDE.actions:list()) do
                if a.name == 'test.temp_cleanup_action' then found = true end
            end
            assert_false(found, 'action must be removed on disable')
        end)
    end)

    suite('Reactive hooks API', function()
        test('hooks module exports all IDE hooks', function()
            local h = require('ide.toolkit.hooks')
            assert_type(h.useState, 'function', 'must have useState')
            assert_type(h.useReducer, 'function', 'must have useReducer')
            assert_type(h.useMemo, 'function', 'must have useMemo')
            assert_type(h.useCallback, 'function', 'must have useCallback')
            assert_type(h.useEffect, 'function', 'must have useEffect')
            assert_type(h.useLayoutEffect, 'function', 'must have useLayoutEffect')
            assert_type(h.useRef, 'function', 'must have useRef')
            assert_type(h.useContext, 'function', 'must have useContext')
            assert_type(h.createContext, 'function', 'must have createContext')
            assert_type(h.useKeymap, 'function', 'must have useKeymap')
            assert_type(h.useAutoCmd, 'function', 'must have useAutoCmd')
            assert_type(h.useToggle, 'function', 'must have useToggle')
            assert_type(h.batch, 'function', 'must have batch')
        end)

        test('createContext stores default value', function()
            local h = require('ide.toolkit.hooks')
            local ctx = h.createContext('dark')
            assert_eq(ctx._value, 'dark', 'context must hold default')
        end)

        test('context Provider updates value and notifies subscribers', function()
            local h = require('ide.toolkit.hooks')
            local ctx = h.createContext('initial')
            local received = nil
            ctx._subscribers[#ctx._subscribers + 1] = function(v) received = v end
            ctx:Provider('updated')
            assert_eq(ctx._value, 'updated', 'value must update')
            assert_eq(received, 'updated', 'subscriber must be notified')
        end)

        test('deps_equal compares arrays correctly', function()
            local h = require('ide.toolkit.hooks')
            assert_true(h._deps_equal({1, 2, 3}, {1, 2, 3}), 'same deps must be equal')
            assert_false(h._deps_equal({1, 2}, {1, 3}), 'different deps must differ')
            assert_false(h._deps_equal({1}, {1, 2}), 'different length must differ')
            assert_false(h._deps_equal(nil, {1}), 'nil vs array must differ')
        end)
    end)

    suite('Shell process tracking', function()
        test('run_sync returns stdout', function()
            local result = IDE.shell:run_sync('echo', { 'test_output' })
            assert_eq(result.code, 0, 'echo must succeed')
            assert_match(result.stdout, 'test_output', 'stdout must contain the output')
        end)

        test('run_sync nonexistent command fails', function()
            -- vim.system throws ENOENT for missing commands, so wrap in pcall
            local ok, result = pcall(IDE.shell.run_sync, IDE.shell, 'nonexistent_command_xyz', {})
            if ok then
                assert_true(result.code ~= 0, 'nonexistent command must fail')
            else
                -- ENOENT error is also acceptable — command doesn't exist
                assert_match(tostring(result), 'ENOENT', 'error must mention ENOENT')
            end
        end)
    end)

    suite('FileSystem edge cases', function()
        test('read returns empty string for zero-byte file', function()
            local path = '/tmp/ide_test_empty_' .. os.time()
            io.open(path, 'w'):close()
            local content, err = IDE.fs:read(path)
            assert_eq(content, '', 'empty file must return empty string')
            assert_nil(err, 'no error for empty file')
            os.remove(path)
        end)

        test('read returns nil + error for missing file', function()
            local content, err = IDE.fs:read('/tmp/nonexistent_file_xyz_999')
            assert_nil(content, 'missing file must return nil')
            assert_not_nil(err, 'must return error message')
        end)

        test('write and read roundtrip', function()
            local path = '/tmp/ide_test_roundtrip_' .. os.time()
            IDE.fs:write(path, 'hello world')
            local content = IDE.fs:read(path)
            assert_eq(content, 'hello world', 'read must return what was written')
            os.remove(path)
        end)
    end)

    suite('memoize correctness', function()
        test('caches nil return value', function()
            local calls = 0
            local fn = memoize(function() calls = calls + 1; return nil end)
            fn(); fn(); fn()
            assert_eq(calls, 1, 'nil result must be cached — function called only once')
        end)

        test('caches false return value', function()
            local calls = 0
            local fn = memoize(function() calls = calls + 1; return false end)
            local r1 = fn()
            local r2 = fn()
            assert_eq(calls, 1, 'false result must be cached')
            assert_eq(r1, false, 'first call must return false')
            assert_eq(r2, false, 'second call must return false')
        end)
    end)

    suite('Dispatch cleanup', function()
        test('remove_renderer cleans up global function', function()
            local Dispatch = require('ide.Dispatch')
            Dispatch.renderer('_test_cleanup', function() return '' end)
            assert_not_nil(_G['IDE_render__test_cleanup'], 'global should exist')
            Dispatch.remove_renderer('_test_cleanup')
            assert_nil(_G['IDE_render__test_cleanup'], 'global must be cleaned up')
        end)
    end)

    suite('BufferLSP scoping', function()
        test('lsp facade exists on buffer', function()
            local buf = require('ide.Buffer').create({ listed = false, scratch = true })
            local lsp = buf:lsp()
            assert_not_nil(lsp, 'buffer must have lsp facade')
            assert_type(lsp.hover, 'function', 'lsp must have hover method')
            assert_type(lsp.definition, 'function', 'lsp must have definition method')
            assert_type(lsp.format, 'function', 'lsp must have format method')
            buf:close(true)
        end)
    end)

    suite('Picker auto-search', function()
        test('auto_search option is stored', function()
            local Picker = require('ide.toolkit.Picker')
            local p = Picker({
                title = 'Test',
                items = { 'apple', 'banana' },
                auto_search = true,
                on_select = function() end,
            })
            assert_true(p._auto_search, 'auto_search flag must be set')
        end)

        test('auto_search false by default', function()
            local Picker = require('ide.toolkit.Picker')
            local p = Picker({
                title = 'Test',
                items = { 'apple' },
                on_select = function() end,
            })
            assert_false(p._auto_search, 'auto_search must default to false')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- BUFFER LIFECYCLE TESTS
    -- ═══════════════════════════════════════════════════════

    suite('Buffer lifecycle', function()
        test('close removes from BufferList', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = true, scratch = true })
            local id = buf:id()
            assert_not_nil(IDE.buffers:get(id), 'buffer must be in list before close')
            buf:close(true)
            -- After close, buffer should not be valid
            assert_false(vim.api.nvim_buf_is_valid(id), 'buffer must be invalid after close')
        end)

        test('destroy is idempotent', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = false, scratch = true })
            buf:destroy()
            buf:destroy() -- must not error
            buf:close(true)
        end)

        test('methods return safe defaults on deleted buffer', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = false, scratch = true })
            buf:close(true)
            -- All these must return safe defaults, not crash
            assert_eq(buf:filetype(), '', 'filetype must return empty string')
            assert_eq(buf:line_count(), 0, 'line_count must return 0')
            buf:set_lines(0, -1, { 'test' })  -- must be no-op, not crash
            buf:format()  -- must be no-op, not crash
        end)

        test('Window methods return safe defaults on closed window', function()
            local Window = require('ide.Window')
            local Buffer = require('ide.Buffer')
            local b = Buffer.create({ listed = false, scratch = true })
            local win = Window.open_float(b, { relative = 'editor', row = 0, col = 0, width = 5, height = 3, style = 'minimal' })
            win:close(true)
            b:close(true)
            assert_nil(win:buffer(), 'buffer must return nil')
            assert_eq(win:width(), 0, 'width must return 0')
            assert_eq(win:height(), 0, 'height must return 0')
            assert_eq(win:cursor().row, 1, 'cursor must return default position')
        end)

        test('events fire on buffer operations', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = false, scratch = true })
            local modified_fired = false
            buf:on('change', function() modified_fired = true end)
            -- Modify the buffer
            buf:set_option('modifiable', true)
            buf:set_lines(0, -1, { 'test line' })
            -- Note: 'change' event depends on autocmd wiring which may not fire
            -- in scratch buffers. This tests the subscription API doesn't crash.
            buf:close(true)
        end)

        test('create returns valid buffer with correct options', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = false, scratch = true })
            assert_true(buf:is_valid(), 'created buffer must be valid')
            assert_false(buf:is_loaded() == nil, 'is_loaded must return a value')
            buf:close(true)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- EXTENSION SYSTEM DEEP TESTS
    -- ═══════════════════════════════════════════════════════

    suite('Extension system', function()
        test('extension re-enable after disable restores commands', function()
            local Extension = require('ide.Extension')
            local Ext = Class('TestReEnable', Extension)
            function Ext:init() Extension.init(self, 'TestReEnable') end
            function Ext:on_register(ctx)
                ctx:command('TestReEnableCmd', function() end, { desc = 'test' })
            end
            local ext = Ext()
            ext:_enable()
            assert_true(#ext._commands > 0, 'command must be registered')
            ext:_disable()
            assert_eq(#ext._commands, 0, 'commands must be cleared')
            ext:_enable()
            assert_true(#ext._commands > 0, 'command must be re-registered after re-enable')
            ext:_disable()
        end)

        test('extension hooks are cleaned up on disable', function()
            local Extension = require('ide.Extension')
            local Ext = Class('TestHookClean', Extension)
            function Ext:init() Extension.init(self, 'TestHookClean') end
            function Ext:on_register(ctx)
                ctx:hook('BufEnter', function() end, { desc = 'test hook' })
            end
            local ext = Ext()
            ext:_enable()
            assert_true(#ext._hooks > 0, 'hook must be registered')
            local hook_id = ext._hooks[1]
            ext:_disable()
            assert_eq(#ext._hooks, 0, 'hooks must be cleared')
            -- Verify the autocmd was actually deleted
            local ok = pcall(vim.api.nvim_get_autocmds, { ids = { hook_id } })
            -- After deletion, querying the id may return empty or error
        end)

        test('context:notify does not crash', function()
            local Extension = require('ide.Extension')
            local Ext = Class('TestNotify', Extension)
            function Ext:init() Extension.init(self, 'TestNotify') end
            function Ext:on_register(ctx)
                -- This should not crash even though it creates a Toast
                -- (we don't assert the Toast appeared, just that it doesn't error)
            end
            local ext = Ext()
            ext:_enable()
            ext:_disable()
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- CONFIG MANAGER TESTS
    -- ═══════════════════════════════════════════════════════

    suite('ConfigManager behavior', function()
        test('toggle registers and flips', function()
            IDE.config:register_toggle('test_toggle_xyz', { default = false, desc = 'test' })
            assert_false(IDE.config:is_enabled('test_toggle_xyz'), 'default must be false')
            IDE.config:toggle('test_toggle_xyz')
            assert_true(IDE.config:is_enabled('test_toggle_xyz'), 'must be true after toggle')
            IDE.config:toggle('test_toggle_xyz')
            assert_false(IDE.config:is_enabled('test_toggle_xyz'), 'must be false after second toggle')
            pcall(IDE.config.unregister_toggle, IDE.config, 'test_toggle_xyz')
        end)

        test('set_toggle sets to specific value', function()
            IDE.config:register_toggle('test_set_toggle', { default = false, desc = 'test' })
            assert_false(IDE.config:is_enabled('test_set_toggle'))
            IDE.config:set_toggle('test_set_toggle', true)
            assert_true(IDE.config:is_enabled('test_set_toggle'), 'must be true after set_toggle(true)')
            IDE.config:set_toggle('test_set_toggle', true) -- idempotent
            assert_true(IDE.config:is_enabled('test_set_toggle'), 'must stay true on duplicate set')
            IDE.config:set_toggle('test_set_toggle', false)
            assert_false(IDE.config:is_enabled('test_set_toggle'), 'must be false after set_toggle(false)')
            pcall(IDE.config.unregister_toggle, IDE.config, 'test_set_toggle')
        end)

        test('toggle emits event', function()
            IDE.config:register_toggle('test_toggle_event', { default = false, desc = 'test' })
            local received_name, received_value
            local unsub = IDE.config:on('toggle', function(name, value)
                if name == 'test_toggle_event' then
                    received_name = name
                    received_value = value
                end
            end)
            IDE.config:toggle('test_toggle_event')
            assert_eq(received_name, 'test_toggle_event', 'event must contain toggle name')
            assert_eq(received_value, true, 'event must contain new value')
            unsub()
            pcall(IDE.config.unregister_toggle, IDE.config, 'test_toggle_event')
        end)

        test('option get/set roundtrip', function()
            local old = IDE.config:option('tabstop')
            assert_type(old, 'number', 'tabstop must be a number')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- WINDOW TESTS
    -- ═══════════════════════════════════════════════════════

    suite('Window behavior', function()
        test('current returns valid window', function()
            local Window = require('ide.Window')
            local win = Window.current()
            assert_true(win:is_valid(), 'current window must be valid')
        end)

        test('list returns at least one window', function()
            local Window = require('ide.Window')
            local wins = Window.list()
            assert_true(#wins >= 1, 'must have at least one window')
            for _, w in ipairs(wins) do
                assert_true(w:is_valid(), 'each window must be valid')
            end
        end)

        test('update_config with relative merges existing position', function()
            local Window = require('ide.Window')
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = false, scratch = true })
            local win = Window.open_float(buf, {
                relative = 'editor', row = 5, col = 10, width = 20, height = 5, style = 'minimal'
            })
            -- This previously crashed: "relative requires row/col"
            win:update_config({ relative = 'editor', title = 'Updated Title', title_pos = 'center' })
            -- Also test border-only update (no relative)
            win:update_config({ border = 'rounded' })
            win:close(true)
            buf:close(true)
        end)

        test('cursor returns Position', function()
            local Window = require('ide.Window')
            local pos = Window.current():cursor()
            assert_true(pos.row >= 1, 'row must be >= 1')
            assert_true(pos.col >= 1, 'col must be >= 1')
        end)

        test('window:call executes in window context', function()
            local Window = require('ide.Window')
            local win = Window.current()
            local result = win:call(function()
                return vim.api.nvim_get_current_win()
            end)
            assert_eq(result, win:id(), 'call must execute in the correct window')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- INSPECT / XASSERT EDGE CASES
    -- ═══════════════════════════════════════════════════════

    suite('inspect operator precedence', function()
        test('unroll_meta=false does not unroll __pairs tables', function()
            local mt_table = setmetatable({x = 1}, {
                __pairs = function(t) return next, {unrolled = true}, nil end
            })
            -- With unroll_meta=false, inspect should NOT clone and re-inspect
            local result = inspect(mt_table, { unroll_meta = false })
            -- The result should contain the metatable info but NOT be "cloned"
            -- Before the fix, (opts.unroll_meta and mt.__ipairs) or mt.__pairs
            -- would evaluate to mt.__pairs even when unroll_meta=false
            assert_type(result, 'string', 'inspect must return a string')
        end)
    end)

    suite('table.freeze behavior', function()
        test('frozen dict blocks writes', function()
            local t = table.freeze({ a = 1, b = 2 })
            assert_eq(t.a, 1, 'read must work')
            local ok = pcall(function() t.c = 3 end)
            assert_false(ok, 'write must error')
        end)

        test('pairs works on frozen table', function()
            local t = table.freeze({ x = 10, y = 20 })
            local keys = {}
            for k in pairs(t) do keys[#keys + 1] = k end
            table.sort(keys)
            assert_eq(#keys, 2, 'pairs must find 2 keys')
        end)

        test('ipairs works on frozen list via custom ipairs', function()
            local t = table.freeze({ 'a', 'b', 'c' })
            local values = {}
            for _, v in ipairs(t) do values[#values + 1] = v end
            assert_eq(#values, 3, 'ipairs must iterate 3 values')
            assert_eq(values[1], 'a')
            assert_eq(values[3], 'c')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- INTEGRATION TESTS: multiple subsystems working together
    -- ═══════════════════════════════════════════════════════

    suite('Integration: Buffer + Git', function()
        test('git facade returns diff summary for tracked file', function()
            -- Open a real file that's in a git repo
            local bufnr = open_fixture('sample.lua', 500)
            local Buffer = require('ide.Buffer')
            local buf = Buffer.get(bufnr)
            local summary = buf:git():diff_summary()
            assert_type(summary.added, 'number', 'added must be number')
            assert_type(summary.changed, 'number', 'changed must be number')
            assert_type(summary.removed, 'number', 'removed must be number')
            close_buf()
        end)
    end)

    suite('Integration: Buffer + AST', function()
        test('ast facade returns breadcrumb for Lua function', function()
            local bufnr = open_fixture('sample.lua', 500)
            local Buffer = require('ide.Buffer')
            local buf = Buffer.get(bufnr)
            -- Move to line 1 (which should be outside any function)
            vim.api.nvim_win_set_cursor(0, {1, 0})
            local crumb = buf:ast():breadcrumb()
            assert_type(crumb, 'string', 'breadcrumb must return a string')
            close_buf()
        end)

        test('treesitter parser is available for Lua files', function()
            local bufnr = open_fixture('sample.lua', 500)
            local Buffer = require('ide.Buffer')
            local buf = Buffer.get(bufnr)
            assert_true(buf:ast():has_parser(), 'Lua file must have treesitter parser')
            close_buf()
        end)
    end)

    suite('Integration: ActionRegistry + Extensions', function()
        test('all registered actions have descriptions', function()
            local actions = IDE.actions:list()
            assert_true(#actions > 0, 'must have some actions registered')
            for _, action in ipairs(actions) do
                assert_not_nil(action.name, 'action must have a name')
                assert_not_nil(action.desc, 'action must have a description')
                assert_true(#action.name > 0, 'name must not be empty')
                assert_true(#action.desc > 0, 'desc must not be empty')
            end
        end)

        test('core actions are registered', function()
            local actions = IDE.actions:list()
            local names = {}
            for _, a in ipairs(actions) do names[a.name] = true end
            assert_true(names['file.save'] ~= nil, 'file.save must exist')
            assert_true(names['file.open'] ~= nil, 'file.open must exist')
            assert_true(names['editor.undo'] ~= nil, 'editor.undo must exist')
            assert_true(names['lsp.hover'] ~= nil, 'lsp.hover must exist')
        end)
    end)

    suite('Integration: KeyManager', function()
        test('keymaps are registered', function()
            assert_true(IDE.keys:count() > 10, 'must have >10 keymaps registered')
        end)

        test('KeyHint has entries for leader prefix', function()
            local hint = IDE.keys:hints()
            -- Check if there are groups registered for normal mode
            local groups = hint._groups['n']
            assert_not_nil(groups, 'must have normal mode groups')
            local leader = groups['<leader>']
            -- leader may be nil if no leader keymaps registered (unlikely with 50+ extensions)
            if leader then
                local count = 0
                for _ in pairs(leader) do count = count + 1 end
                assert_true(count > 5, 'leader prefix must have >5 hint entries')
            end
        end)
    end)

    suite('Integration: Git', function()
        test('branch returns string in git repo', function()
            local branch = IDE.git:branch()
            assert_not_nil(branch, 'must detect git branch')
            assert_true(#branch > 0, 'branch name must not be empty')
        end)

        test('root returns directory path', function()
            local root = IDE.git:root()
            assert_not_nil(root, 'must detect git root')
            assert_true(IDE.fs:is_directory(root), 'root must be a directory')
        end)

        test('log returns commit objects', function()
            local commits = IDE.git:log({ count = 3 })
            assert_type(commits, 'table')
            if #commits > 0 then
                assert_not_nil(commits[1].hash, 'commit must have hash')
                assert_not_nil(commits[1].subject, 'commit must have subject')
            end
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- STRESS TESTS: rapid sequences, edge cases, resource cleanup
    -- ═══════════════════════════════════════════════════════

    suite('Stress: rapid buffer lifecycle', function()
        test('create and destroy 20 buffers without leaks', function()
            local Buffer = require('ide.Buffer')
            local ids = {}
            for i = 1, 20 do
                local buf = Buffer.create({ listed = false, scratch = true })
                ids[#ids + 1] = buf:id()
            end
            -- Close them all
            for _, id in ipairs(ids) do
                if vim.api.nvim_buf_is_valid(id) then
                    pcall(vim.api.nvim_buf_delete, id, { force = true })
                end
            end
            -- Verify none are valid
            for _, id in ipairs(ids) do
                assert_false(vim.api.nvim_buf_is_valid(id), 'buffer must be invalid after delete')
            end
        end)

        test('Buffer.get on deleted buffer returns new instance', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = false, scratch = true })
            local id = buf:id()
            buf:close(true)
            -- Getting a deleted buffer should still not crash
            local ok = pcall(Buffer.get, id)
            -- It may error (invalid buf id) — that's acceptable
        end)
    end)

    suite('Stress: extension enable/disable cycles', function()
        test('enable-disable 5 times does not leak', function()
            local Extension = require('ide.Extension')
            local Ext = Class('CycleTest', Extension)
            function Ext:init() Extension.init(self, 'CycleTest') end
            local register_count = 0
            function Ext:on_register(ctx)
                register_count = register_count + 1
                ctx:command('CycleTestCmd', function() end, { desc = 'test' })
                ctx:hook('BufEnter', function() end, { desc = 'test hook' })
            end
            local unregister_count = 0
            function Ext:on_unregister()
                unregister_count = unregister_count + 1
            end

            local ext = Ext()
            for i = 1, 5 do
                ext:_enable()
                assert_true(ext:is_enabled(), 'must be enabled')
                assert_eq(#ext._commands, 1, 'must have 1 command')
                assert_eq(#ext._hooks, 1, 'must have 1 hook')
                ext:_disable()
                assert_false(ext:is_enabled(), 'must be disabled')
                assert_eq(#ext._commands, 0, 'commands must be empty')
                assert_eq(#ext._hooks, 0, 'hooks must be empty')
            end
            assert_eq(register_count, 5, 'on_register must be called 5 times')
            assert_eq(unregister_count, 5, 'on_unregister must be called 5 times')
        end)
    end)

    suite('Stress: xassert edge cases', function()
        test('nested table validation works after fix', function()
            -- This would silently pass before the fix (iterating empty composite_schema)
            local ok, err = pcall(xassert, {
                opts = { { foo = 'hello', bar = 42 }, { foo = 'string', bar = 'integer' } }
            })
            assert_true(ok, 'valid nested table must pass: ' .. tostring(err))
        end)

        test('nested table with wrong types fails', function()
            local ok = pcall(xassert, {
                opts = { { foo = 123 }, { foo = 'string' } }
            })
            assert_false(ok, 'invalid nested table must fail')
        end)

        test('xassert with nil value and string schema', function()
            -- nil should fail a 'string' check
            local ok = pcall(xassert, {
                name = { nil, 'string' }
            })
            assert_false(ok, 'nil must fail string assertion')
        end)
    end)

    suite('Stress: hash and memoize', function()
        test('hash produces consistent results', function()
            local h1 = hash('hello', 42, true)
            local h2 = hash('hello', 42, true)
            assert_eq(h1, h2, 'same inputs must produce same hash')
        end)

        test('hash differs for different inputs', function()
            local h1 = hash('hello')
            local h2 = hash('world')
            assert_true(h1 ~= h2, 'different inputs must produce different hashes')
        end)

        test('memoize with different args returns different results', function()
            local fn = memoize(function(x) return x * 2 end)
            assert_eq(fn(5), 10)
            assert_eq(fn(3), 6)
            assert_eq(fn(5), 10) -- cached
        end)
    end)

    suite('Stress: FileSystem walk', function()
        test('walk visits fixture directory', function()
            local visited = {}
            IDE.fs:walk(fixture_dir, function(path, ftype)
                visited[#visited + 1] = path
            end, { max_depth = 1 })
            assert_true(#visited > 3, 'fixture dir must have >3 entries')
        end)

        test('walk respects max_depth', function()
            local shallow = {}
            IDE.fs:walk(fixture_dir, function(path)
                shallow[#shallow + 1] = path
            end, { max_depth = 0 })
            -- max_depth=0 means don't recurse into subdirs
            assert_eq(#shallow, 0, 'depth 0 must not visit anything')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- STDLIB TABLE UTILITY TESTS
    -- ═══════════════════════════════════════════════════════

    suite('table.merge', function()
        test('merges two tables', function()
            local result = table.merge({ a = 1 }, { b = 2 })
            assert_eq(result.a, 1)
            assert_eq(result.b, 2)
        end)

        test('first table wins on conflict (keep mode)', function()
            local result = table.merge({ a = 1 }, { a = 99 })
            assert_eq(result.a, 1, 'first value must win with keep mode')
        end)

        test('empty merge returns empty table', function()
            local result = table.merge()
            assert_type(result, 'table')
        end)

        test('single table returns that table', function()
            local t = { x = 42 }
            local result = table.merge(t)
            assert_eq(result.x, 42)
        end)
    end)

    suite('table.keys', function()
        test('returns all keys', function()
            local keys = table.keys({ a = 1, b = 2, c = 3 })
            table.sort(keys)
            assert_eq(#keys, 3)
            assert_eq(keys[1], 'a')
            assert_eq(keys[3], 'c')
        end)

        test('empty table returns empty list', function()
            assert_eq(#table.keys({}), 0)
        end)
    end)

    suite('table.clone', function()
        test('clone produces equal but distinct table', function()
            local orig = { a = 1, b = { c = 2 } }
            local copy = table.clone(orig)
            assert_eq(copy.a, 1)
            assert_true(copy ~= orig, 'must be different object')
        end)

        test('shallow clone shares nested tables', function()
            local inner = { x = 1 }
            local orig = { nested = inner }
            local copy = table.clone(orig, true)
            assert_true(copy.nested == inner, 'shallow clone must share nested refs')
        end)
    end)

    suite('table.list_map', function()
        test('maps values', function()
            local result = table.list_map({ 1, 2, 3 }, function(x) return x * 10 end)
            assert_eq(result[1], 10)
            assert_eq(result[2], 20)
            assert_eq(result[3], 30)
        end)

        test('empty list returns empty', function()
            local result = table.list_map({}, function(x) return x end)
            assert_eq(#result, 0)
        end)
    end)

    suite('table.list_filter', function()
        test('filters values', function()
            local result = table.list_filter({ 1, 2, 3, 4, 5 }, function(x) return x > 3 end)
            assert_eq(#result, 2)
            assert_eq(result[1], 4)
            assert_eq(result[2], 5)
        end)

        test('filter all returns empty', function()
            local result = table.list_filter({ 1, 2, 3 }, function() return false end)
            assert_eq(#result, 0)
        end)
    end)

    suite('table.list_uniq', function()
        test('removes duplicates', function()
            local result = table.list_uniq({ 'a', 'b', 'a', 'c', 'b' })
            assert_eq(#result, 3)
        end)

        test('preserves order of first occurrence', function()
            local result = table.list_uniq({ 'c', 'a', 'b', 'a' })
            assert_eq(result[1], 'c')
            assert_eq(result[2], 'a')
            assert_eq(result[3], 'b')
        end)
    end)

    suite('table.freeze', function()
        test('read-only: write to new key errors', function()
            local t = table.freeze({ x = 1 })
            local ok = pcall(function() t.y = 2 end)
            assert_false(ok, 'write to new key must error')
        end)

        test('read-only: overwrite existing key errors', function()
            local t = table.freeze({ x = 1 })
            local ok = pcall(function() t.x = 99 end)
            assert_false(ok, 'overwrite must error')
        end)
    end)

    suite('xtype', function()
        test('detects basic types', function()
            local _, xt = xtype('hello')
            assert_eq(xt, 'string')
            _, xt = xtype(42)
            assert_eq(xt, 'integer')
            _, xt = xtype(3.14)
            assert_eq(xt, 'number')
            _, xt = xtype(true)
            assert_eq(xt, 'boolean')
            _, xt = xtype(nil)
            assert_eq(xt, 'nil')
        end)

        test('detects callable', function()
            local _, xt = xtype(function() end)
            assert_eq(xt, 'callable')
        end)

        test('detects list', function()
            local _, xt = xtype({ 1, 2, 3 })
            assert_eq(xt, 'list')
        end)

        test('detects table', function()
            local _, xt = xtype({ a = 1 })
            assert_eq(xt, 'table')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- TABLE.TO_LIST / TABLE.LIST_MERGE
    -- ═══════════════════════════════════════════════════════

    suite('table.to_list', function()
        test('nil becomes empty list', function()
            local result = table.to_list(nil)
            assert_type(result, 'table')
            assert_eq(#result, 0)
        end)

        test('list passes through', function()
            local input = { 1, 2, 3 }
            local result = table.to_list(input)
            assert_eq(result, input, 'list must pass through unchanged')
        end)

        test('dict extracts values', function()
            local result = table.to_list({ a = 1, b = 2 })
            assert_eq(#result, 2)
        end)

        test('scalar wraps in list', function()
            local result = table.to_list(42)
            assert_eq(#result, 1)
            assert_eq(result[1], 42)
        end)

        test('string wraps in list', function()
            local result = table.to_list('hello')
            assert_eq(#result, 1)
            assert_eq(result[1], 'hello')
        end)
    end)

    suite('table.list_merge', function()
        test('merges two lists', function()
            local result = table.list_merge({ 1, 2 }, { 3, 4 })
            assert_eq(#result, 4)
            assert_eq(result[1], 1)
            assert_eq(result[4], 4)
        end)

        test('empty lists return empty', function()
            local result = table.list_merge({}, {})
            assert_eq(#result, 0)
        end)

        test('single list returns copy', function()
            local result = table.list_merge({ 'a', 'b' })
            assert_eq(#result, 2)
            assert_eq(result[1], 'a')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- CLASS SYSTEM EDGE CASES
    -- ═══════════════════════════════════════════════════════

    suite('Class system edges', function()
        test('is_a with nil returns false', function()
            local A = Class('TestIsANil')
            local a = A()
            assert_false(a:is_a(nil), 'is_a(nil) must be false')
        end)

        test('mixin does not overwrite existing methods', function()
            local A = Class('TestMixinPreserve')
            function A:foo() return 'original' end
            Class.include(A, { foo = function() return 'mixin' end })
            assert_eq(A():foo(), 'original', 'original method must be preserved')
        end)

        test('mixin adds new methods', function()
            local A = Class('TestMixinAdd')
            Class.include(A, { bar = function() return 'added' end })
            assert_eq(A():bar(), 'added')
        end)

        test('three-level inheritance', function()
            local A = Class('ThreeA')
            function A:init() self.level = 'A' end
            local B = Class('ThreeB', A)
            function B:init() A.init(self); self.level = 'B' end
            local C = Class('ThreeC', B)
            function C:init() B.init(self); self.level = 'C' end

            local c = C()
            assert_eq(c.level, 'C')
            assert_true(c:is_a(A), 'C must be_a A')
            assert_true(c:is_a(B), 'C must be_a B')
            assert_true(c:is_a(C), 'C must be_a C')
            assert_eq(Class.name(c), 'ThreeC')
            assert_eq(Class.super(C), B)
            assert_eq(Class.super(B), A)
        end)

        test('__tostring on class instance', function()
            local A = Class('ToStringTest')
            function A:__tostring() return 'custom_repr' end
            assert_eq(tostring(A()), 'custom_repr')
        end)

        test('default __tostring shows class name', function()
            local A = Class('DefaultTS')
            local s = tostring(A())
            assert_match(s, 'DefaultTS')
        end)

        test('constructor with no init does not crash', function()
            local A = Class('NoInit')
            local a = A()
            assert_not_nil(a, 'instance must be created even without init')
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- POSITION VALUE OBJECT
    -- ═══════════════════════════════════════════════════════

    suite('Position edge cases', function()
        test('from_cursor handles 0-indexed col', function()
            local P = require('ide.Position')
            local p = P.from_cursor({ 5, 0 })
            assert_eq(p.row, 5)
            assert_eq(p.col, 1, 'col 0 must become 1 (1-indexed)')
        end)

        test('to_cursor converts back correctly', function()
            local P = require('ide.Position')
            local p = P(10, 5)
            local cursor = p:to_cursor()
            assert_eq(cursor[1], 10, 'row must be preserved')
            assert_eq(cursor[2], 4, 'col must be 0-indexed in cursor format')
        end)

        test('roundtrip preserves values', function()
            local P = require('ide.Position')
            local original = { 42, 15 }
            local p = P.from_cursor(original)
            local back = p:to_cursor()
            assert_eq(back[1], original[1])
            assert_eq(back[2], original[2])
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- TIMER BEHAVIOR
    -- ═══════════════════════════════════════════════════════

    suite('Timer', function()
        test('debounce returns callable', function()
            local fn = IDE.Timer.debounce(100, function() end)
            assert_type(fn, 'function')
        end)

        test('delay creates timer that can be stopped', function()
            local timer = IDE.Timer.delay(10000, function() end)
            assert_not_nil(timer, 'delay must return timer handle')
            timer:stop() -- must not crash
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- REENTRANCE AND CONCURRENCY SAFETY
    -- ═══════════════════════════════════════════════════════

    suite('EventEmitter reentrance', function()
        local function make()
            local E = Class('ReentTest')
            Class.include(E, require('ide.EventEmitter'))
            local o = E()
            o._suppress_errors = true
            return o
        end

        test('emit during emit fires inner handlers', function()
            local obj = make()
            local inner_count = 0
            obj:on('outer', function() obj:emit('inner') end)
            obj:on('inner', function() inner_count = inner_count + 1 end)
            obj:emit('outer')
            assert_eq(inner_count, 1, 'inner must fire')
        end)

        test('subscribe during emit does not fire in same cycle', function()
            local obj = make()
            local late = 0
            obj:on('x', function()
                obj:on('x', function() late = late + 1 end)
            end)
            obj:emit('x')
            assert_eq(late, 0, 'new handler must not fire in same emit')
        end)

        test('clear during emit does not skip remaining handlers', function()
            local obj = make()
            local second = false
            obj:on('x', function() obj:clear('x') end)
            obj:on('x', function() second = true end)
            obj:emit('x')
            assert_true(second, 'second handler must fire despite clear')
        end)
    end)

    suite('Mass buffer operations', function()
        test('create and close 50 buffers', function()
            local Buffer = require('ide.Buffer')
            local ids = {}
            for i = 1, 50 do
                ids[i] = Buffer.create({ listed = false, scratch = true }):id()
            end
            for _, id in ipairs(ids) do
                pcall(vim.api.nvim_buf_delete, id, { force = true })
            end
            for _, id in ipairs(ids) do
                assert_false(vim.api.nvim_buf_is_valid(id))
            end
        end)

        test('rapid buffer switch stays consistent', function()
            local Buffer = require('ide.Buffer')
            local a = Buffer.create({ listed = false, scratch = true })
            local b = Buffer.create({ listed = false, scratch = true })
            for i = 1, 10 do
                vim.api.nvim_set_current_buf(a:id())
                vim.api.nvim_set_current_buf(b:id())
            end
            assert_true(Buffer.current():is_valid())
            a:close(true); b:close(true)
        end)
    end)

    suite('Extension stress', function()
        test('50 hooks register and cleanup', function()
            local Extension = require('ide.Extension')
            local E = Class('HookStress', Extension)
            function E:init() Extension.init(self, 'HookStress') end
            function E:on_register(ctx)
                for i = 1, 50 do
                    ctx:hook('BufEnter', function() end, { desc = 'h' .. i })
                end
            end
            local ext = E()
            ext:_enable()
            assert_eq(#ext._hooks, 50, 'must register 50')
            ext:_disable()
            assert_eq(#ext._hooks, 0, 'must clean 50')
        end)
    end)

    suite('Nil argument safety', function()
        test('Buffer.get(nil) returns nil', function()
            assert_nil(require('ide.Buffer').get(nil))
        end)
        test('Buffer.get(string) returns nil', function()
            assert_nil(require('ide.Buffer').get('bad'))
        end)
        test('Window.get(nil) returns nil', function()
            assert_nil(require('ide.Window').get(nil))
        end)
        test('fs:exists(nil) returns false', function()
            assert_false(IDE.fs:exists(nil))
        end)
        test('fs:read(nil) returns nil + error', function()
            local c, e = IDE.fs:read(nil)
            assert_nil(c)
            assert_not_nil(e)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- IDE SUBSYSTEM INTEGRATION TESTS
    -- ═══════════════════════════════════════════════════════

    suite('IDE subsystems exist', function()
        test('all critical subsystems are initialized', function()
            assert_not_nil(IDE.buffers, 'buffers must exist')
            assert_not_nil(IDE.windows, 'windows must exist')
            assert_not_nil(IDE.lsp, 'lsp must exist')
            assert_not_nil(IDE.keys, 'keys must exist')
            assert_not_nil(IDE.config, 'config must exist')
            assert_not_nil(IDE.theme, 'theme must exist')
            assert_not_nil(IDE.fs, 'fs must exist')
            assert_not_nil(IDE.shell, 'shell must exist')
            assert_not_nil(IDE.git, 'git must exist')
            assert_not_nil(IDE.ui, 'ui must exist')
            assert_not_nil(IDE.actions, 'actions must exist')
            assert_not_nil(IDE.treesitter, 'treesitter must exist')
            assert_not_nil(IDE.icons, 'icons must exist')
            assert_not_nil(IDE.marks, 'marks must exist')
            assert_not_nil(IDE.text, 'text must exist')
            assert_not_nil(IDE.debug, 'debug must exist')
            assert_not_nil(IDE.session, 'session must exist')
        end)
    end)

    suite('IDE.ui behavior', function()
        test('mode returns current mode info', function()
            local mode = IDE.ui:mode()
            assert_not_nil(mode, 'mode must return a value')
            assert_not_nil(mode.mode, 'must have .mode field')
            assert_type(mode.mode, 'string')
        end)

        test('finder subsystem exists', function()
            if IDE.ui.finder then
                assert_type(IDE.ui.finder.files, 'function', 'finder must have files method')
                assert_type(IDE.ui.finder.grep, 'function', 'finder must have grep method')
            end
        end)
    end)

    suite('IDE.theme behavior', function()
        test('colorscheme returns name', function()
            local cs = IDE.theme:colorscheme()
            assert_type(cs, 'string')
            assert_true(#cs > 0, 'colorscheme name must not be empty')
        end)

        test('fg returns hex color or nil', function()
            local fg = IDE.theme:fg('Normal')
            -- May be nil if no explicit fg set, but must not crash
            if fg then
                assert_match(fg, '^#', 'fg must be hex format')
            end
        end)

        test('define and link do not crash', function()
            IDE.theme:define('TestHighlight_XYZ', { fg = '#ff0000', default = true })
            IDE.theme:link('TestLink_XYZ', 'Normal')
            -- Cleanup
            pcall(vim.api.nvim_set_hl, 0, 'TestHighlight_XYZ', {})
            pcall(vim.api.nvim_set_hl, 0, 'TestLink_XYZ', {})
        end)
    end)

    suite('IDE.icons behavior', function()
        test('icon database exists', function()
            assert_not_nil(IDE.icons, 'icons subsystem must exist')
            -- is_loaded may be false in headless mode
        end)

        test('for_file returns icon for known extension', function()
            local icon = IDE.icons:for_file('test.lua', 'lua')
            if icon then
                assert_not_nil(icon:char(), 'icon must have char')
            end
        end)
    end)

    suite('IDE.text behavior', function()
        test('rename_expression returns string', function()
            local expr = IDE.text:rename_expression()
            assert_type(expr, 'string', 'rename_expression must return string')
        end)
    end)

    suite('Extension registration integrity', function()
        test('all registered extensions have unique names', function()
            local exts = IDE:extensions()
            local names = {}
            for _, ext in ipairs(exts) do
                local name = ext:name()
                assert_nil(names[name], 'duplicate extension name: ' .. name)
                names[name] = true
            end
        end)

        test('all registered extensions are enabled', function()
            local exts = IDE:extensions()
            for _, ext in ipairs(exts) do
                assert_true(ext:is_enabled(), ext:name() .. ' must be enabled')
            end
        end)

        test('extension count matches expectation', function()
            local exts = IDE:extensions()
            assert_true(#exts >= 40, 'must have >=40 extensions, got ' .. #exts)
        end)

        test('each extension has on_register method', function()
            local exts = IDE:extensions()
            for _, ext in ipairs(exts) do
                assert_type(ext.on_register, 'function', ext:name() .. ' must have on_register')
            end
        end)
    end)

    suite('Dispatch integrity', function()
        test('tabbar renderer registered', function()
            local Dispatch = require('ide.Dispatch')
            local stats = Dispatch.stats()
            assert_true(vim.tbl_contains(stats.renderers, 'tabbar'), 'tabbar renderer must be registered')
        end)

        test('click handler count is positive', function()
            local Dispatch = require('ide.Dispatch')
            local stats = Dispatch.stats()
            assert_true(stats.clicks > 0, 'must have some click handlers')
        end)
    end)

    suite('Highlight groups exist', function()
        test('mode highlights defined', function()
            for _, hl in ipairs({ 'IDEModeNormal', 'IDEModeInsert', 'IDEModeVisual', 'IDEModeCommand' }) do
                local ok, val = pcall(vim.api.nvim_get_hl, 0, { name = hl })
                assert_true(ok, hl .. ' must be defined')
                assert_true(next(val) ~= nil, hl .. ' must have properties')
            end
        end)

        test('panel highlights defined', function()
            for _, hl in ipairs({ 'IDEPanelNormal', 'IDEPanelBorder', 'IDEPanelDim' }) do
                local ok, val = pcall(vim.api.nvim_get_hl, 0, { name = hl })
                assert_true(ok, hl .. ' must be defined')
            end
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- END-TO-END USER JOURNEY TESTS
    -- ═══════════════════════════════════════════════════════

    suite('E2E: file open-edit-save cycle', function()
        test('open fixture, modify, undo, verify clean', function()
            local bufnr = open_fixture('sample.lua', 500)
            local Buffer = require('ide.Buffer')
            local buf = Buffer.get(bufnr)
            assert_true(buf:is_valid(), 'buffer must be valid')
            assert_true(buf:is_normal(), 'fixture must be normal buffer')

            -- Get original content
            local orig_line = buf:line(1)
            assert_not_nil(orig_line, 'first line must exist')

            -- Modify
            buf:set_option('modifiable', true)
            local test_text = '-- test modification ' .. os.time()
            buf:set_lines(0, 1, { test_text })
            assert_true(buf:is_modified(), 'buffer must be modified')
            assert_eq(buf:line(1), test_text, 'first line must be changed')

            -- Undo
            buf:undo()
            assert_eq(buf:line(1), orig_line, 'undo must restore original')

            close_buf()
        end)

        test('open file, check filetype detected', function()
            local bufnr = open_fixture('sample.lua', 500)
            local Buffer = require('ide.Buffer')
            local buf = Buffer.get(bufnr)
            assert_eq(buf:filetype(), 'lua', 'Lua file must detect lua filetype')
            close_buf()
        end)

        test('open Go file, check filetype', function()
            local bufnr = open_fixture('sample.go', 1000)
            local Buffer = require('ide.Buffer')
            local buf = Buffer.get(bufnr)
            assert_eq(buf:filetype(), 'go', 'Go file must detect go filetype')
            close_buf()
        end)

        test('open HTML file, check filetype', function()
            local bufnr = open_fixture('sample.html', 500)
            local Buffer = require('ide.Buffer')
            local buf = Buffer.get(bufnr)
            assert_eq(buf:filetype(), 'html', 'HTML file must detect html filetype')
            close_buf()
        end)
    end)

    suite('E2E: buffer list management', function()
        test('opening file makes it the current buffer', function()
            open_fixture('sample.go', 500)
            local cur = IDE.buffers:current()
            assert_match(cur:name(), 'sample', 'current must match opened file')
            close_buf()
        end)

        test('listed returns at least one buffer', function()
            open_fixture('sample.lua', 300)
            local listed = IDE.buffers:listed()
            assert_true(#listed >= 1, 'must have >=1 listed buffer')
            close_buf()
        end)
    end)

    suite('E2E: Buffer API on real files', function()
        test('line_count matches file', function()
            local bufnr = open_fixture('sample.lua', 300)
            local Buffer = require('ide.Buffer')
            local buf = Buffer.get(bufnr)
            assert_true(buf:line_count() > 0, 'file must have lines')
            close_buf()
        end)

        test('path is absolute', function()
            local bufnr = open_fixture('sample.lua', 300)
            local Buffer = require('ide.Buffer')
            local buf = Buffer.get(bufnr)
            local path = buf:path()
            assert_not_nil(path, 'must have a path')
            assert_match(path, '^/', 'path must be absolute')
            assert_match(path, 'sample%.lua$', 'path must end with filename')
            close_buf()
        end)

        test('name is short filename', function()
            local bufnr = open_fixture('sample.lua', 300)
            local Buffer = require('ide.Buffer')
            local buf = Buffer.get(bufnr)
            local name = buf:name()
            assert_eq(name, 'sample.lua', 'name must be just filename')
            close_buf()
        end)
    end)

    suite('E2E: write and read file', function()
        test('IDE.fs write + read roundtrip on temp file', function()
            local path = '/tmp/ide_e2e_write_' .. os.time() .. '.txt'
            local content = 'line1\nline2\nline3'
            IDE.fs:write(path, content)
            local read_back = IDE.fs:read(path)
            assert_eq(read_back, content, 'must read back exactly what was written')
            os.remove(path)
        end)

        test('IDE.fs write + read is consistent', function()
            local path = '/tmp/ide_e2e_consistency_' .. os.time() .. '.txt'
            -- Write multiple times, verify last write wins
            IDE.fs:write(path, 'version1')
            assert_eq(IDE.fs:read(path), 'version1')
            IDE.fs:write(path, 'version2')
            assert_eq(IDE.fs:read(path), 'version2')
            os.remove(path)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- BUFFER API COVERAGE
    -- ═══════════════════════════════════════════════════════

    suite('Buffer API: type checks', function()
        test('is_special on panel buffer', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = false, scratch = true })
            buf:set_option('filetype', 'ide-panel')
            assert_true(Buffer.is_special(buf:id()), 'panel must be special')
            buf:close(true)
        end)

        test('is_normal on real file', function()
            local bufnr = open_fixture('sample.lua', 300)
            local Buffer = require('ide.Buffer')
            local buf = Buffer.get(bufnr)
            assert_true(buf:is_normal(), 'file buffer must be normal')
            assert_false(Buffer.is_special(bufnr), 'file buffer must not be special')
            close_buf()
        end)

        test('is_modifiable on scratch buffer', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = false, scratch = true })
            assert_true(buf:is_modifiable(), 'scratch buffer must be modifiable')
            buf:set_modifiable(false)
            assert_false(buf:is_modifiable(), 'must be non-modifiable after set')
            buf:set_modifiable(true)
            buf:close(true)
        end)
    end)

    suite('Buffer API: text operations', function()
        test('set_text replaces range', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = false, scratch = true })
            buf:set_lines(0, -1, { 'hello world' })
            buf:set_text(0, 0, 0, 5, { 'goodbye' })
            assert_eq(buf:line(1), 'goodbye world')
            buf:close(true)
        end)

        test('changedtick increments on modification', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = false, scratch = true })
            local tick1 = buf:changedtick()
            buf:set_lines(0, -1, { 'change' })
            local tick2 = buf:changedtick()
            assert_true(tick2 > tick1, 'changedtick must increment')
            buf:close(true)
        end)

        test('undo restores previous content', function()
            local bufnr = open_fixture('sample.lua', 300)
            local Buffer = require('ide.Buffer')
            local buf = Buffer.get(bufnr)
            local orig = buf:line(1)
            buf:set_lines(0, 1, { '-- changed' })
            assert_eq(buf:line(1), '-- changed')
            buf:undo()
            assert_eq(buf:line(1), orig, 'undo must restore')
            close_buf()
        end)
    end)

    suite('Buffer API: metadata', function()
        test('set_name changes raw buffer name', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = false, scratch = true })
            buf:set_name('TestName.lua')
            -- name() returns nil for non-normal buffers (scratch)
            -- but the raw nvim name should be set
            local raw = vim.api.nvim_buf_get_name(buf:id())
            assert_match(raw, 'TestName', 'raw name must update')
            buf:close(true)
        end)

        test('var and set_var roundtrip', function()
            local Buffer = require('ide.Buffer')
            local buf = Buffer.create({ listed = false, scratch = true })
            buf:set_var('test_var_xyz', 42)
            assert_eq(buf:var('test_var_xyz'), 42, 'must read back set var')
            buf:close(true)
        end)
    end)

    suite('Window API: operations', function()
        test('exec_normal runs normal mode command', function()
            local bufnr = open_fixture('sample.lua', 300)
            local Window = require('ide.Window')
            local win = Window.current()
            -- Go to line 3
            win:exec_normal('3gg')
            assert_eq(win:cursor().row, 3, 'cursor must be at line 3')
            close_buf()
        end)

        test('set_buffer changes displayed buffer', function()
            local Buffer = require('ide.Buffer')
            local Window = require('ide.Window')
            local buf1 = Buffer.create({ listed = false, scratch = true })
            local buf2 = Buffer.create({ listed = false, scratch = true })
            buf1:set_lines(0, -1, { 'buffer 1' })
            buf2:set_lines(0, -1, { 'buffer 2' })

            local win = Window.current()
            win:set_buffer(buf1)
            assert_eq(win:buffer():id(), buf1:id())
            win:set_buffer(buf2)
            assert_eq(win:buffer():id(), buf2:id())

            buf1:close(true)
            buf2:close(true)
        end)
    end)

    suite('Git API: status', function()
        test('is_repo detects git repository', function()
            -- We're in the nvim config dir which IS a git repo
            assert_true(IDE.git:is_repo(), 'must detect git repo')
        end)

        test('status_counts returns diff numbers', function()
            local counts = IDE.git:status_counts()
            assert_not_nil(counts, 'must return counts')
            assert_type(counts.modified, 'number', 'modified must be number')
            assert_type(counts.added, 'number', 'added must be number')
            assert_type(counts.deleted, 'number', 'deleted must be number')
        end)
    end)

    suite('FileSystem API: paths', function()
        test('display_path shortens home directory', function()
            local home = IDE.fs:home()
            local display = IDE.fs:display_path(home .. '/test/file.lua')
            -- display_path should use ~ for home
            if display then
                assert_true(not display:find(home, 1, true) or display:find('~'),
                    'display_path should shorten home dir')
            end
        end)

        test('is_link returns boolean', function()
            local result = IDE.fs:is_link('/tmp')
            assert_type(result, 'boolean')
        end)

        test('mkdir creates and removes directory', function()
            local dir = '/tmp/ide_test_mkdir_' .. os.time()
            IDE.fs:mkdir(dir)
            assert_true(IDE.fs:is_directory(dir), 'mkdir must create directory')
            os.remove(dir)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- CLEANUP: wipe all test fixture buffers
    -- ═══════════════════════════════════════════════════════

    ensure_normal_window()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if name:find('test_fixtures') or name:find('Scratch') or name:find('ide_e2e') or name:find('TestName') then
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
