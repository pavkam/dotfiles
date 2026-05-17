-- Test Runner Extension: runs the IDE test suite and provides neotest keybindings.
-- Provides :IDETest command and <leader>t* keybindings for project tests.

local Extension = require 'ide.Extension'

local TestRunner = Class('TestRunner', Extension)

function TestRunner:init()
    Extension.init(self, 'TestRunner')
end

--- Clear test module entries from package.loaded.
--- load_fresh handles re-reading from disk; this just ensures
--- the test modules aren't returned from package.loaded.
local function clear_test_modules()
    package.loaded['ide.test'] = nil
    package.loaded['ide.test_extended'] = nil
    package.loaded['ide.test_visual'] = nil
end

--- Load a test module fresh from disk, bypassing ALL bytecode caches.
--- Uses io.open + load to avoid vim.loader cache issues.
---@param mod_name string
---@return table
local function load_fresh(mod_name)
    package.loaded[mod_name] = nil
    local path = IDE.fs:join(IDE.fs:config_dir(), 'lua', mod_name:gsub('%.', '/') .. '.lua')
    local f = io.open(path, 'r')
    if not f then error('Failed to open ' .. path) end
    local src = f:read('*a')
    f:close()
    local chunk, err = load(src, '@' .. path)
    if not chunk then error('Failed to load ' .. path .. ': ' .. (err or '?')) end
    local result = chunk()
    package.loaded[mod_name] = result
    return result
end

--- Save the current buffer if modified before running tests.
---@return boolean # true if safe to proceed
local function ensure_saved()
    local buf = IDE.buffers:current()
    if buf and buf:is_modified() then buf:save() end
    return true
end

function TestRunner:on_register(ctx)
    ctx:command('IDETest', function()
        clear_test_modules()

        IDE.ui:info('Running base tests...', { title = 'IDETest' })
        vim.cmd('redraw')
        local base = load_fresh('ide.test').run()

        IDE.ui:info(string.format('Base: %d/%d. Running extended tests...',
            base.passed, base.total), { title = 'IDETest' })
        vim.cmd('redraw')
        local ext = load_fresh('ide.test_extended').run()

        local total_pass = base.passed + ext.passed
        local total_fail = base.failed + ext.failed
        local total = total_pass + total_fail
        local summary = string.format('%d/%d passed, %d failed (base: %d, extended: %d)',
            total_pass, total, total_fail, base.total, ext.total)

        local f = io.open('/tmp/ide_all_tests.txt', 'w')
        if f then f:write(summary .. '\n'); f:close() end

        if total_fail > 0 then
            IDE.ui:error('Tests: ' .. summary)
        else
            IDE.ui:info('Tests: ' .. summary)
        end
    end, { desc = 'Run full IDE test suite' })

    -- Neotest keybindings (project test runner)
    -- These use pcall since neotest is lazy-loaded and may not be available.

    ctx:keymap('n', '<leader>tr', function()
        local ok, neotest = pcall(require, 'neotest')
        if not ok then return end
        if ensure_saved() then neotest.run.run() end
    end, { desc = 'Run nearest test' })

    ctx:keymap('n', '<leader>tf', function()
        local ok, neotest = pcall(require, 'neotest')
        if not ok then return end
        local buf = IDE.buffers:current()
        local path = buf and buf:path()
        if path then neotest.run.run(path) end
    end, { desc = 'Run file tests' })

    ctx:keymap('n', '<leader>td', function()
        if not ensure_saved() then return end
        local buf = IDE.buffers:current()
        local ft = buf and buf:filetype() or ''
        if ft == 'go' then
            local dok, dap_go = pcall(require, 'dap-go')
            if dok then dap_go.debug_test() end
        else
            local ok, neotest = pcall(require, 'neotest')
            if ok then neotest.run.run { strategy = 'dap', suite = false } end
        end
    end, { desc = 'Debug nearest test' })

    ctx:keymap('n', '<leader>tU', function()
        local ok, neotest = pcall(require, 'neotest')
        if ok then neotest.summary.toggle() end
    end, { desc = 'Toggle test summary panel' })

    ctx:keymap('n', '<leader>to', function()
        local ok, neotest = pcall(require, 'neotest')
        if ok then neotest.output.open() end
    end, { desc = 'Show test output' })

    ctx:keymap('n', '<leader>tw', function()
        local ok, neotest = pcall(require, 'neotest')
        if ok then neotest.watch.toggle() end
    end, { desc = 'Toggle test watching' })

    -- Register the <leader>t group for which-key
    IDE.keys:group('<leader>t', { desc = 'Testing' })
end

return TestRunner

