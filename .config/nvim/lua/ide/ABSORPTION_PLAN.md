# Plugin Absorption Plan — The Bold Path to Zero External UI Dependencies

## Vision
Replace 9 external plugins (~41,000 lines) with ~4,800 lines of focused, owned code.
Every Neovim quirk buried under clean OOP. Only IDE is a singleton. Buffer owns its world.

## Current State
- 37 extensions, 13 plugin files, 29 legacy lua files
- 653/653 tests passing
- 6 irreducible extension violations (sign API, spell commands)
- Buffer-centric API established (buf:lsp, buf:ast, buf:git, buf:diagnostics)

---

## PHASE 0: Fix Foundations
> Must complete before ANY absorption. ~410 lines of infrastructure work.

### Step 0.1: Shell Enhancement — Cancellable + Streaming Processes
**What:** `Shell:run()` currently discards the process handle. Add `run_cancellable()` that returns a handle with `:kill()`, and `run_streaming()` for line-by-line stdout callbacks.
**Why:** Plans 2,3,4 all need to cancel running processes. Telescope replacement needs streaming file results. Formatter runner needs to pipe stdin and kill stale processes.
**How:**
```lua
-- Shell:run_cancellable(cmd, args, opts) → ProcessHandle
-- ProcessHandle:kill(), :on_stdout(cb), :on_stderr(cb), :on_exit(cb), :wait()
-- Shell:run_streaming(cmd, args, opts) → ProcessHandle (same, but calls on_stdout per line)
```
**Tests:** Unit test process spawning, killing, streaming output. Integration test with `echo` and `cat`.
**Effort:** ~140 lines
**Blocks:** Plans 2, 3, 4

### Step 0.2: Panel Refactor — Position, Dismiss, Resize
**What:** Panel currently only supports center-of-editor floating. Needs configurable position (center/bottom/left/right/cursor), opt-in auto-dismiss (not forced), and VimResized handling.
**Why:** FuzzyPicker needs bottom-of-screen (ivy), cmdline needs top-center, tree needs left sidebar. The forced WinLeave dismiss breaks multi-window layouts.
**How:**
- Add `position` option to Panel:init() — 'center' (default), 'bottom', 'top', 'left', 'right', 'cursor', or {row, col}
- Move WinLeave auto-dismiss behind `opts.auto_dismiss = true` (default false)
- Add VimResized hook that calls `:_update_layout()`
- Rename `set_nui_lines` → `set_styled_lines`
**Tests:** Unit test each position mode. Visual test panel at different positions.
**Effort:** ~100 lines delta
**Blocks:** Plans 1, 2, 3

### Step 0.3: FileSystem Additions — Directory Operations + Watching
**What:** Add `list()`, `stat()`, `walk()`, `watch()`, `copy()`, `delete_recursive()` to FileSystem.
**Why:** File tree needs directory listing. Fuzzy finder needs recursive file scanning. Tree needs filesystem watching for auto-refresh.
**How:**
```lua
FileSystem:list(dir)              → { {name, type, size}... }  -- wraps uv.fs_opendir + readdir
FileSystem:stat(path)             → { type, size, mtime }      -- wraps uv.fs_stat
FileSystem:walk(dir, cb, opts)    → nil                         -- recursive, async via uv
FileSystem:watch(path, cb)        → unwatch_fn                  -- wraps uv.fs_event
FileSystem:copy(src, dst)         → boolean, err
FileSystem:delete_recursive(path) → boolean, err
```
**Tests:** Unit test each method with temp directories. Integration test watch callback fires.
**Effort:** ~120 lines
**Blocks:** Plans 2, 3

### Step 0.4: Git Per-File Status
**What:** Add `Git:file_status(path)` and `Git:status_map(cwd)` for per-file git status.
**Why:** File tree decorations and fuzzy picker file icons need per-file git status (modified/added/untracked/etc).
**How:**
```lua
Git:status_map(cwd) → { [path] = 'M'|'A'|'?'|'!' }  -- parses `git status --porcelain`
Git:file_status(path) → string|nil
Git:is_ignored(path) → boolean                         -- `git check-ignore`
```
**Tests:** Unit test with fixture repo. Integration test status_map returns expected statuses.
**Effort:** ~50 lines added to Git.lua
**Blocks:** Plans 2, 3

### Step 0.5: Shell Floating Terminal — Decouple from lazy.util
**What:** `Shell:floating()` currently calls `require('lazy.util').float_term()`. Replace with own implementation using Window + terminal buffer.
**Why:** Core class should not depend on a plugin manager's utility functions.
**How:** Create terminal buffer with `vim.fn.termopen()`, display in a floating window using `Window.open_float()`.
**Tests:** Visual test floating terminal opens and closes cleanly.
**Effort:** ~30 lines
**Blocks:** Architectural integrity

### Step 0.6: Dynamic Buffer Classification Registry
**What:** `Buffer.SPECIAL_FILETYPES` is a hardcoded list with plugin-specific strings ('TelescopePrompt', 'neo-tree', 'WhichKey'). Replace with a dynamic registry.
**Why:** When plugins are absorbed, their filetypes change or disappear. Extensions should register their own special filetypes.
**How:**
```lua
Buffer.register_special_filetype('my_picker_prompt')
Buffer.unregister_special_filetype('TelescopePrompt')  -- after telescope absorption
```
**Tests:** Unit test register/unregister. Verify is_special() uses the dynamic set.
**Effort:** ~20 lines
**Blocks:** Cleanup during each absorption

---

## PHASE 1: Shared Toolkit Components
> Build once, used by multiple absorptions. ~860 lines.

### Step 1.1: ManagedFloat — Lifecycle-Managed Floating Window
**What:** Toolkit class that wraps Window+Buffer with mount/unmount lifecycle, positioning, z-index, dismiss policies, resize handling.
**Why:** Needed by noice (message popups), telescope (3-pane layout), neo-tree (sidebar), and general toolkit.
**How:**
```lua
local mf = ManagedFloat({
    position = 'center',        -- or {row=3, col='50%'} or 'bottom' or 'cursor'
    width = 80, height = 20,    -- or '80%' or 'auto'
    border = 'rounded',
    title = 'My Float',
    zindex = 50,
    dismiss = { keys = {'q', '<Esc>'}, on_leave = true },
})
mf:mount()                      -- create window + buffer, set up autocmds
mf:set_styled_lines(lines)      -- render content
mf:update_layout({width = 100}) -- resize without remount
mf:hide()                       -- hide but keep buffer
mf:show()                       -- show again
mf:unmount()                    -- destroy everything, clean up
```
**Tests:** Unit test mount/unmount lifecycle. Visual test positioning at each mode. Test z-index stacking.
**Effort:** ~200 lines
**Blocks:** Plans 1, 2, 3

### Step 1.2: InputField — Embeddable Text Input
**What:** Toolkit component for inline text input with keystroke handling, cursor, and change callbacks.
**Why:** Fuzzy picker needs a prompt field. Enhanced cmdline needs text input. File tree needs rename/create input.
**How:**
```lua
local input = InputField({
    prompt = '> ',
    placeholder = 'Search...',
    on_change = function(text) ... end,   -- called on every keystroke
    on_submit = function(text) ... end,   -- called on <CR>
    on_cancel = function() ... end,       -- called on <Esc>
})
input:mount(buf, row)           -- render into a buffer at a specific row
input:focus()                   -- set cursor into the input
input:get_text()                -- current input text
input:set_text(text)            -- programmatic set
```
**Tests:** Unit test text input/output. Test on_change fires on each keystroke. Test submit/cancel.
**Effort:** ~180 lines
**Blocks:** Plans 1, 2

### Step 1.3: FuzzyScorer — FZF Algorithm via FFI
**What:** Wrapper around the FZF native C library for fuzzy matching and scoring.
**Why:** Telescope replacement needs fast fuzzy matching. File palette extension needs it too.
**How:** Vendor `fzf_lib.lua` (86 lines FFI wrapper) + `libfzf.so` (compiled binary) from telescope-fzf-native. Wrap in an IDE class.
```lua
local scorer = FuzzyScorer({ case_mode = 'smart', fuzzy = true })
local score = scorer:score('init.lua', 'inl')     -- returns number (0 = no match)
local positions = scorer:positions('init.lua', 'inl')  -- returns {1,3,5} (match positions)
scorer:destroy()                                   -- free C resources
```
**Tests:** Unit test scoring accuracy. Test case sensitivity modes. Test position highlighting.
**Effort:** ~150 lines + vendored files
**Blocks:** Plan 2

### Step 1.4: TreeView — Hierarchical Data Component
**What:** Toolkit component for expandable/collapsible tree rendering with lazy child loading.
**Why:** File explorer needs a tree view. Could be reused for outline, symbols, etc.
**How:**
```lua
local tree = TreeView({
    title = 'Explorer',
    position = 'float',         -- or 'left' for sidebar
    render_node = function(node, depth)
        local line = StyledLine()
        line:append(indent(depth))
        line:append(node.is_dir and '▸ ' or '  ')
        line:append(StyledText(node.name, node.is_dir and 'Directory' or 'Normal'))
        return line
    end,
    on_expand = function(node, callback)
        -- async load children
        callback(children)
    end,
    on_select = function(node) ... end,
})
tree:set_root(root_node)
tree:expand('path/to/dir')
tree:focus_node('path/to/file')
tree:show()
```
**Tests:** Unit test expand/collapse. Test lazy loading via callback. Visual test tree renders correctly.
**Effort:** ~300 lines (includes TreeNode value object)
**Blocks:** Plan 3

### Step 1.5: VirtualText — Extmark Wrapper with Lifecycle
**What:** Value object for virtual text placement with automatic cleanup.
**Why:** Message routing (inline), git signs (gutter), lint diagnostics (inline errors) all need managed virtual text.
**How:**
```lua
local vt = VirtualText(buf, {
    line = 5,                    -- 0-indexed
    text = ' 3 errors',
    hl = 'DiagnosticError',
    position = 'eol',           -- or 'overlay', 'right_align'
})
vt:show()
vt:update({ text = ' 2 errors' })
vt:hide()
vt:destroy()                    -- remove extmark
```
**Tests:** Unit test show/hide/update/destroy lifecycle. Test multiple VTs don't interfere.
**Effort:** ~80 lines
**Blocks:** Plans 1, 3, 4

---

## PHASE 2: Absorb conform + nvim-lint (First Absorption)
> Smallest surface, no UI needed, just Shell + config. ~1,400 lines, removes 2 plugins.

### Step 2.1: Formatter/Linter Configuration Registry
**What:** Add `IDE.config:formatters_for(ft)` and `IDE.config:linters_for(ft)` registries.
**How:** Static tables in config, loaded during IDE init. Each entry: `{ cmd, args, stdin, cwd_fn, condition_fn }`.
**Effort:** ~100 lines (config tables for 13 formatters + 12 linters)

### Step 2.2: Diff-Based Text Edit Application
**What:** Port conform's `apply_format()` logic — diff old vs new buffer content, apply as minimal text edits.
**Why:** Replacing entire buffer content causes cursor jump and undo history pollution. Diff-based edits preserve cursor and create clean undo points.
**How:** Use `vim.diff()` with `result_type = 'indices'`, convert to LSP text edits, apply via `vim.lsp.util.apply_text_edits()`.
**Effort:** ~100 lines (ported from conform runner.lua)

### Step 2.3: Buffer:format() Rewrite
**What:** Replace `pcall(require, 'conform')` in Buffer:format() with owned formatter running.
**How:** Resolve formatters from config by filetype → chain them sequentially (stdin→process→stdout) → diff-apply result.
**Tests:** Unit test formatter resolution. Integration test with stylua on a Lua fixture. E2E test format keybinding.
**Effort:** ~250 lines (FormatterRunner logic)

### Step 2.4: Buffer:lint() Rewrite
**What:** Replace `pcall(require, 'lint')` in Buffer:lint() with owned linter running.
**How:** Resolve linters from config by filetype → spawn process → parse output → set diagnostics.
**Tests:** Unit test linter resolution. Integration test with luacheck on a Lua fixture.
**Effort:** ~200 lines (LinterRunner logic)

### Step 2.5: Format-on-Save + Lint-on-Change Extensions
**What:** Wire format/lint into BufWritePre/BufWritePost hooks via extensions.
**Effort:** ~60 lines (2 small extensions)

### Step 2.6: Remove Plugins + Verify
**What:** Delete `lua/plugins/conform.lua` and `lua/plugins/nvim-lint.lua`. Run full test suite.
**Follow-up tasks (for later iterations):**
- [ ] Port the `injected` formatter (treesitter-based code block formatting in markdown)
- [ ] Add `:IDEFormatters` and `:IDELinters` status commands showing active tools per buffer
- [ ] Migrate the legacy `plugin.lua` formatter/linter slot system (used by buf.lua) into the new config registry

---

## PHASE 3: Absorb neo-tree (Second Absorption)
> ~1,100 lines, removes 2 plugins (neo-tree + nui.nvim).

### Step 3.1: FileTree Core Rewrite
**What:** Rewrite `lua/ide/FileTree.lua` from a 36-line proxy into a real tree manager (~400 lines).
**How:** Owns tree state (root, expanded dirs, watchers). Uses FileSystem for scanning, Git for decorations, TreeView for rendering.
**Tests:** Unit test expand/collapse/refresh. Integration test with fixture directory.
**Effort:** ~400 lines

### Step 3.2: File Explorer Extension
**What:** Extension with `:IDEExplorer` command, `<leader>e` keymap, follow-current-file behavior.
**Tests:** E2E test toggle opens/closes tree. E2E test reveal finds current file.
**Effort:** ~100 lines

### Step 3.3: Remove Plugins + Verify
**What:** Delete `lua/plugins/neo-tree.lua`. Remove nui.nvim dependency. Run full test suite.
**Follow-up tasks:**
- [ ] Add file tree keymaps for create/delete/rename/copy/move with IDE.fs operations
- [ ] Add file watcher integration for auto-refresh on external changes
- [ ] Add diagnostic count indicators on tree nodes
- [ ] Support split-panel mode (left sidebar) in addition to float

---

## PHASE 4: Absorb noice + nvim-notify (Third Absorption)
> ~1,100 lines, removes 3 plugins. HIGHEST RISK due to vim.ui_attach.

### Step 4.1: Message + MessageRouter Core Classes
**What:** `Message` value object + `MessageRouter` class that intercepts `vim.ui_attach` and routes messages to views based on filter rules.
**Tests:** Unit test message filtering. Integration test route matching. CRITICAL: test that vim.ui_attach doesn't cause infinite loops.
**Effort:** ~300 lines

### Step 4.2: CommandLine Toolkit Component
**What:** Floating command-line replacement rendered at top-center with contextual icons and syntax highlighting.
**Tests:** Visual E2E test cmdline appears on `:`, `/`, `?`. Test cursor tracking. Test dismiss on `<Esc>`.
**Effort:** ~250 lines

### Step 4.3: MessageRouting Extension
**What:** Extension that ports our 7 noice route rules (suppress file-save messages, redirect undo/redo to mini, etc).
**Tests:** E2E test noisy messages are suppressed. Test error messages show in popup.
**Effort:** ~150 lines

### Step 4.4: LspDocs Extension
**What:** Enhanced LSP hover/signature rendering with scrolling support and markdown override.
**Effort:** ~200 lines

### Step 4.5: Remove Plugins + Verify
**What:** Delete `lua/plugins/noice.lua`. Remove nui.nvim and nvim-notify. Run full test suite.
**Follow-up tasks:**
- [ ] Port noice's LSP progress rendering to the mini view
- [ ] Add message history command (:IDEMessages)
- [ ] Investigate vim.ui_attach edge cases (blocking mode, fast_event guards)

---

## PHASE 5: Absorb telescope (Fourth Absorption, Last)
> ~1,230 lines, removes 2 plugins. Most complex UI.

### Step 5.1: FuzzyPicker Toolkit Component
**What:** 3-window layout (prompt + results + preview) with real-time fuzzy scoring.
**How:** Uses ManagedFloat for windows, InputField for prompt, FuzzyScorer for matching, DataSource for data.
**Tests:** Unit test scoring loop. Visual E2E test picker opens, filters, selects. Test each layout preset (horizontal, dropdown, cursor, ivy).
**Effort:** ~400 lines

### Step 5.2: DataSource — Async Data Providers
**What:** `from_table()`, `from_command()`, `from_live_command()`, `from_function()`.
**Tests:** Unit test each source type. Integration test streaming from `rg`.
**Effort:** ~150 lines

### Step 5.3: Finder Rewrite
**What:** Rewrite Finder.lua from a telescope proxy to a FuzzyPicker coordinator.
**How:** Each finder method (files, grep, references, etc.) creates a DataSource + FuzzyPicker config.
**Tests:** E2E test each finder method opens picker and returns results.
**Effort:** ~300 lines

### Step 5.4: Port Custom Pickers
**What:** Rewrite `file-palette.lua` and `ui_select.lua` to use FuzzyPicker instead of telescope primitives.
**Effort:** ~100 lines

### Step 5.5: Remove Plugins + Verify
**What:** Delete `lua/plugins/telescope.lua`. Remove telescope + fzf-native. Run full test suite. Consider removing plenary.nvim if no other plugin needs it.
**Follow-up tasks:**
- [ ] Add picker history (remember last query per picker type)
- [ ] Add multi-select support (C-q sends to quickfix)
- [ ] Performance optimization for 100K+ file projects
- [ ] Preview panel with treesitter highlighting

---

## PHASE 6: MainMenu — Turbo Pascal-Style Menu Bar
> The crown jewel. A proper menu bar replacing the tabline. ~800 lines.

### Vision
```
┌─[ File ]──[ Edit ]──[ View ]──[ Build ]──[ Debug ]──[ Git ]──[ Help ]──────────────┐
│                                                                                     │
│  ┌─ File ──────────┐                                                                │
│  │ 📄 New File     │                                                                │
│  │ 📂 Open File    │                                                                │
│  │ 📋 Recent Files │                                                                │
│  │ ─────────────── │                                                                │
│  │ 💾 Save      ⌘S │                                                                │
│  │ 💾 Save All  ⇧⌘S│                                                                │
│  │ ─────────────── │                                                                │
│  │ 📝 Rename       │                                                                │
│  │ 🗑  Delete       │                                                                │
│  │ ─────────────── │                                                                │
│  │ ⚙  Settings     │                                                                │
│  │ ✕  Quit      ⌘Q │                                                                │
│  └──────────────────┘                                                                │
```

Menus change contextually:
- **Go file open?** Build menu shows `Run`, `Test`, `Debug` with Go commands
- **TypeScript project?** Build shows `tsc`, `eslint`, `jest`
- **LSP attached?** Edit menu shows `Rename Symbol`, `Code Action`, `Format`
- **Git repo?** Git menu shows `Stage`, `Commit`, `Push`, `Lazygit`
- **No LSP?** Rename/CodeAction items are grayed out or hidden

### Architecture

#### Step 6.1: MenuBar Toolkit Component (~250 lines)
**What:** Renders into vim.o.tabline. Shows top-level menu items. Handles click and Alt+key to open dropdowns.
**How:** Uses `%@click_handler@` tabline syntax for mouse clicks. Alt+F/E/V/B/D/G/H opens menus via keymaps.
```lua
local MenuBar = Class('MenuBar')

function MenuBar:init() end

--- Register a top-level menu.
---@param name string            -- 'File', 'Edit', etc.
---@param opts { key?: string, priority?: integer }
function MenuBar:add_menu(name, opts) end

--- Register a menu item.
---@param menu string            -- parent menu name
---@param item MenuItem
function MenuBar:add_item(menu, item) end

--- Register a separator.
function MenuBar:add_separator(menu) end

--- Remove all items from a menu (for context rebuild).
function MenuBar:clear_menu(menu) end

--- Open a dropdown menu.
function MenuBar:open(menu_name) end

--- Close any open dropdown.
function MenuBar:close() end

--- Render the tabline string.
---@return string
function MenuBar:render() end
```

#### Step 6.2: MenuItem Value Object (~40 lines)
```lua
---@class MenuItem
---@field text string              -- display text
---@field icon? string             -- nerd font icon
---@field shortcut? string         -- display shortcut (e.g. '⌘S')
---@field action? fun()            -- callback
---@field enabled? fun(): boolean  -- dynamic enable/disable
---@field visible? fun(): boolean  -- dynamic show/hide
---@field submenu? MenuItem[]      -- nested submenu
---@field separator? boolean       -- is this a separator line
```

#### Step 6.3: MenuDropdown Toolkit Component (~200 lines)
**What:** Floating window that renders a menu's items. Handles j/k navigation, Enter to select, h/l for submenu/parent, Esc to close. Mouse hover highlights.
**How:** Uses ManagedFloat positioned directly below the menu bar item.
```lua
local MenuDropdown = Class('MenuDropdown')

function MenuDropdown:init(menu_bar, menu_name, items) end
function MenuDropdown:show(anchor_col) end  -- anchor below tabline at col
function MenuDropdown:close() end
function MenuDropdown:select_item(index) end
function MenuDropdown:navigate(direction) end  -- 'up', 'down', 'left', 'right'
```

#### Step 6.4: MainMenu Extension (~200 lines)
**What:** Extension that registers the menu bar, populates default menus, and updates them contextually.
**How:** Uses `ctx:hook` on BufEnter/LspAttach/LspDetach/FileType to rebuild context-sensitive items.
```lua
local MainMenu = Class('MainMenu', IDE.Extension)

function MainMenu:on_register(ctx)
    IDE.menu_bar = MenuBar()
    
    -- File menu (always present)
    IDE.menu_bar:add_menu('File', { key = 'f' })
    IDE.menu_bar:add_item('File', { text = 'New File',     icon = '📄', action = ... })
    IDE.menu_bar:add_item('File', { text = 'Open File',    icon = '📂', action = ..., shortcut = '⌘O' })
    IDE.menu_bar:add_item('File', { text = 'Recent Files', icon = '📋', action = ... })
    IDE.menu_bar:add_separator('File')
    IDE.menu_bar:add_item('File', { text = 'Save',         icon = '💾', action = ..., shortcut = '⌘S' })
    IDE.menu_bar:add_item('File', { text = 'Save All',     icon = '💾', action = ..., shortcut = '⇧⌘S' })
    ...
    
    -- Edit menu (context-sensitive)
    IDE.menu_bar:add_menu('Edit', { key = 'e' })
    IDE.menu_bar:add_item('Edit', { text = 'Undo',         shortcut = 'u',    action = ... })
    IDE.menu_bar:add_item('Edit', { text = 'Redo',         shortcut = 'U',    action = ... })
    IDE.menu_bar:add_separator('Edit')
    IDE.menu_bar:add_item('Edit', { text = 'Format',       shortcut = '=',    action = ...,
        enabled = function() return Buffer.current():is_normal() end })
    IDE.menu_bar:add_item('Edit', { text = 'Rename Symbol', shortcut = 'C-r',
        action = function() Buffer.current():lsp():rename() end,
        visible = function() return Buffer.current():lsp():has_capability('textDocument/rename') end })
    IDE.menu_bar:add_item('Edit', { text = 'Code Action',   shortcut = 'M-CR',
        action = function() Buffer.current():lsp():code_action() end,
        visible = function() return Buffer.current():lsp():is_attached() end })
    
    -- View menu
    IDE.menu_bar:add_menu('View', { key = 'v' })
    IDE.menu_bar:add_item('View', { text = 'Explorer',     icon = '📁', action = ..., shortcut = '<leader>e' })
    IDE.menu_bar:add_item('View', { text = 'Find Files',   icon = '🔍', action = ..., shortcut = '<leader>f' })
    IDE.menu_bar:add_item('View', { text = 'Grep',         icon = '🔎', action = ..., shortcut = 'M-f' })
    IDE.menu_bar:add_separator('View')
    IDE.menu_bar:add_item('View', { text = 'Diagnostics',           action = ... })
    IDE.menu_bar:add_item('View', { text = 'Quick Fix',             action = ... })
    IDE.menu_bar:add_item('View', { text = 'Toggle Options', icon = '⚙', action = ..., shortcut = '<leader>u' })
    
    -- Build menu (context-sensitive per project type)
    IDE.menu_bar:add_menu('Build', { key = 'b' })
    ctx:hook({ 'BufEnter', 'LspAttach' }, function()
        self:_rebuild_build_menu()
    end)
    
    -- Debug menu
    IDE.menu_bar:add_menu('Debug', { key = 'd' })
    IDE.menu_bar:add_item('Debug', { text = 'Start/Continue', shortcut = '<leader>dc', action = ... })
    IDE.menu_bar:add_item('Debug', { text = 'Toggle Breakpoint', shortcut = '<leader>db', action = ... })
    ...
    
    -- Git menu  
    IDE.menu_bar:add_menu('Git', { key = 'g' })
    IDE.menu_bar:add_item('Git', { text = 'Status',      action = ... })
    IDE.menu_bar:add_item('Git', { text = 'Lazygit',     action = ..., shortcut = '<leader>g',
        visible = function() return IDE.shell:has('lazygit') end })
    IDE.menu_bar:add_item('Git', { text = 'Branches',    action = ... })
    IDE.menu_bar:add_item('Git', { text = 'Commits',     action = ... })
    
    -- Help menu
    IDE.menu_bar:add_menu('Help', { key = 'h' })
    IDE.menu_bar:add_item('Help', { text = 'Keymaps',    action = ... })
    IDE.menu_bar:add_item('Help', { text = 'IDE Status',  action = ... })
    IDE.menu_bar:add_item('Help', { text = 'Extensions',  action = ... })
    IDE.menu_bar:add_item('Help', { text = 'Run Tests',   action = ... })
    IDE.menu_bar:add_item('Help', { text = 'Check Health', action = ... })
    
    -- Alt+key navigation
    for _, menu_name in ipairs({'File','Edit','View','Build','Debug','Git','Help'}) do
        local key = menu_name:sub(1,1):lower()
        ctx:keymap('n', '<M-' .. key .. '>', function()
            IDE.menu_bar:open(menu_name)
        end, { desc = menu_name .. ' menu' })
    end
    
    -- Wire into tabline
    vim.o.tabline = '%!v:lua.IDE_menu_bar_render()'
    _G.IDE_menu_bar_render = function() return IDE.menu_bar:render() end
end

function MainMenu:_rebuild_build_menu()
    IDE.menu_bar:clear_menu('Build')
    local project = IDE:project()
    local pt = project and project:type()
    
    if pt == 'go' then
        IDE.menu_bar:add_item('Build', { text = 'Go Run',    action = ... })
        IDE.menu_bar:add_item('Build', { text = 'Go Test',   action = ... })
        IDE.menu_bar:add_item('Build', { text = 'Go Build',  action = ... })
    elseif pt == 'typescript' or pt == 'javascript' then
        IDE.menu_bar:add_item('Build', { text = 'npm run',   action = ... })
        IDE.menu_bar:add_item('Build', { text = 'npm test',  action = ... })
    elseif pt == 'python' then
        IDE.menu_bar:add_item('Build', { text = 'Run Script', action = ... })
        IDE.menu_bar:add_item('Build', { text = 'pytest',     action = ... })
    end
    
    -- Always available
    IDE.menu_bar:add_separator('Build')
    IDE.menu_bar:add_item('Build', { text = 'Run Command...', icon = '$', action = ... })
end
```

#### Step 6.5: ctx:menu() Extension Slot
**What:** Extensions can register their own menu items. This is the slot pattern — any extension can contribute to any menu.
```lua
-- In an extension:
function MyExt:on_register(ctx)
    ctx:menu('Tools', {
        { text = 'Markdown Preview', action = function() ... end,
          visible = function() return Buffer.current():filetype() == 'markdown' end },
    })
end
```

### Tests
- Unit test MenuBar:add_menu/add_item/clear_menu
- Unit test MenuItem visibility/enabled callbacks
- Unit test MenuDropdown positioning relative to menu bar items
- Visual E2E test: Alt+F opens File menu, Esc closes it
- Visual E2E test: menu items appear/disappear based on context (LSP attached vs not)

### Effort: ~800 lines total (250 MenuBar + 40 MenuItem + 200 MenuDropdown + 200 MainMenu ext + 100 tests + ctx:menu slot)

---

## Summary

| Phase | What | New Code | Removes | Plugins After |
|-------|------|----------|---------|---------------|
| 0 | Foundations | ~410 lines | — | 13 |
| 1 | Toolkit | ~910 lines | — | 13 |
| 2 | conform + nvim-lint | ~710 lines | 2 plugins | 11 |
| 3 | neo-tree + nui | ~500 lines | 2 plugins | 9 |
| 4 | noice + notify | ~900 lines | 3 plugins | 6 |
| 5 | telescope + fzf | ~950 lines | 2 plugins | 4 |
| 6 | MainMenu | ~800 lines | — | 4 |
| **Total** | | **~5,180 lines** | **9 plugins** | **4 plugin files** |

### Final plugin state (4 files):
1. `dap.lua` — Debug Adapter Protocol (irreplaceable)
2. `lspconfig.lua` + `mason.lua` — LSP infrastructure (irreplaceable)
3. `treesitter.lua` — Parser registry (irreplaceable)
4. `tokyonight.lua` — Theme (could absorb palette eventually)
5. `lazydev.lua` — Dev-time Lua type hints (keep)
6. `neotest.lua` — Test framework (keep for now)
7. `supermaven.lua` — AI completion (external service)

Plus `lazy.nvim` as the plugin loader.
