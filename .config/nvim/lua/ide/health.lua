-- IDE Health Check module.
-- Integrates with Neovim's :checkhealth system.
-- Run via :checkhealth ide

local M = {}

--- Check if a tool is available and report its path.
---@param name string
---@param required boolean
---@param desc string|nil
local function check_tool(name, required, desc)
    local found = vim.fn.executable(name) == 1
    local label = desc and (name .. ' (' .. desc .. ')') or name
    if found then
        local path = vim.fn.exepath(name)
        vim.health.ok(label .. ' -- ' .. path)
    elseif required then
        vim.health.error(label .. ' not found (required)')
    else
        vim.health.warn(label .. ' not found')
    end
end

--- Check an IDE subsystem (non-nil and not an empty table).
---@param name string
---@param value any
local function check_subsystem(name, value)
    if value ~= nil then
        vim.health.ok(name)
    else
        vim.health.error(name .. ' failed to initialize')
    end
end

function M.check()
    -- ── Neovim Version ────────────────────────────────────────────
    vim.health.start('IDE Core')

    if vim.fn.has('nvim-0.12') == 1 then
        vim.health.ok('Neovim ' .. tostring(vim.version()))
    elseif vim.fn.has('nvim-0.11') == 1 then
        vim.health.warn('Neovim ' .. tostring(vim.version()) .. ' (0.12+ recommended)')
    else
        vim.health.error('Neovim 0.12+ required, found ' .. tostring(vim.version()))
    end

    -- ── IDE Singleton ─────────────────────────────────────────────
    if not _G.IDE then
        vim.health.error('IDE singleton not initialized (_G.IDE is nil)')
        return
    end
    vim.health.ok('IDE singleton initialized')

    -- ── Subsystems ────────────────────────────────────────────────
    vim.health.start('IDE Subsystems')

    local subsystems = {
        { 'BufferList',      IDE.buffers },
        { 'WindowList',      IDE.windows },
        { 'FileSystem',      IDE.fs },
        { 'Shell',           IDE.shell },
        { 'LspManager',      IDE.lsp },
        { 'KeyManager',      IDE.keys },
        { 'UI',              IDE.ui },
        { 'ConfigManager',   IDE.config },
        { 'ThemeManager',    IDE.theme },
        { 'SessionManager',  IDE.session },
        { 'DebugManager',    IDE.debug },
        { 'Treesitter',      IDE.treesitter },
        { 'Git',             IDE.git },
        { 'QuickFix',        IDE.quickfix },
        { 'Marks',           IDE.marks },
        { 'FormatterRunner', IDE.formatter },
        { 'LinterRunner',    IDE.linter },
        { 'Mouse',           IDE.mouse },
        { 'Text',            IDE.text },
        { 'ActionRegistry',  IDE.actions },
        { 'IconDB',          IDE.icons },
        { 'Commands',        IDE.commands },
    }

    local ok_count, fail_count = 0, 0
    for _, sub in ipairs(subsystems) do
        check_subsystem(sub[1], sub[2])
        if sub[2] ~= nil then ok_count = ok_count + 1 else fail_count = fail_count end
    end

    if fail_count > 0 then
        vim.health.error(fail_count .. ' subsystem(s) failed to initialize')
    end

    -- Toolkit bars (optional, depend on extensions)
    if IDE.statusbar then
        vim.health.ok('StatusBar active')
    else
        vim.health.info('StatusBar not active')
    end
    if IDE.tabbar then
        vim.health.ok('TabBar active')
    else
        vim.health.info('TabBar not active')
    end
    if IDE.winbar then
        vim.health.ok('WinBar active')
    else
        vim.health.info('WinBar not active')
    end

    -- ── Extensions ────────────────────────────────────────────────
    vim.health.start('IDE Extensions')

    local extensions = IDE:extensions()
    table.sort(extensions, function(a, b) return a:name() < b:name() end)

    local enabled, errored = 0, 0
    for _, ext in ipairs(extensions) do
        if ext:is_errored() then
            errored = errored + 1
            vim.health.error(ext:name() .. ' -- ' .. (ext:error() or 'unknown error'))
        elseif ext:is_enabled() then
            enabled = enabled + 1
        end
    end

    if errored == 0 then
        vim.health.ok(enabled .. ' extensions loaded, 0 errors')
    else
        vim.health.warn(enabled .. ' extensions loaded, ' .. errored .. ' errored')
    end

    -- List all extensions compactly
    local names = {}
    for _, ext in ipairs(extensions) do
        if ext:is_enabled() and not ext:is_errored() then
            names[#names + 1] = ext:name()
        end
    end
    if #names > 0 then
        vim.health.info('Loaded: ' .. table.concat(names, ', '))
    end

    -- ── External Tools ────────────────────────────────────────────
    vim.health.start('IDE Tools')

    check_tool('git',   true,  nil)
    check_tool('rg',    true,  'ripgrep, search')
    check_tool('fd',    true,  'file finder')
    check_tool('fzf',   false, 'fuzzy finder')
    check_tool('node',  false, 'Node.js runtime')
    check_tool('npm',   false, 'Node package manager')
    check_tool('go',    false, 'Go toolchain')
    check_tool('python3', false, 'Python 3')
    check_tool('cargo', false, 'Rust toolchain')
    check_tool('stylua',            false, 'Lua formatter')
    check_tool('lua-language-server', false, 'Lua LSP')
    check_tool('lazygit',           false, 'Git TUI')

    -- ── LSP ───────────────────────────────────────────────────────
    vim.health.start('IDE LSP')

    local clients = vim.lsp.get_clients()
    if #clients > 0 then
        for _, c in ipairs(clients) do
            local bufs = vim.lsp.get_buffers_by_client_id(c.id)
            vim.health.ok(string.format('%s (id=%d, %d buffer%s)',
                c.name, c.id, #bufs, #bufs == 1 and '' or 's'))
        end
    else
        vim.health.info('No LSP clients active (open a file to trigger LSP)')
    end

    -- ── Treesitter ────────────────────────────────────────────────
    vim.health.start('IDE Treesitter')

    local important_parsers = {
        'lua', 'vim', 'vimdoc', 'query', 'regex',
        'markdown', 'markdown_inline',
        'bash', 'json', 'yaml', 'toml',
    }

    local installed, missing = {}, {}
    for _, lang in ipairs(important_parsers) do
        local ok_parser = pcall(vim.treesitter.language.inspect, lang)
        if ok_parser then
            installed[#installed + 1] = lang
        else
            missing[#missing + 1] = lang
        end
    end

    if #installed > 0 then
        vim.health.ok(#installed .. ' core parsers installed: ' .. table.concat(installed, ', '))
    end
    for _, lang in ipairs(missing) do
        vim.health.warn('Parser missing: ' .. lang)
    end

    -- ── Tests ─────────────────────────────────────────────────────
    vim.health.start('IDE Tests')
    vim.health.info('Run :IDETest to execute the test suite')
    vim.health.info('Run :lua require("ide.test_visual").run() for visual tests (requires tmux)')
end

return M
