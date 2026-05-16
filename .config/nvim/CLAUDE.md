# Neovim IDE — OOP Abstraction Layer

This is not a "dotfiles" repo. This is a **custom IDE built on top of Neovim** using Lua OOP classes. The goal is to hide every Neovim quirk behind clean, composable abstractions so that building IDE features feels like writing normal application code — not fighting a 30-year-old text editor.

## Philosophy

1. **Abstraction is the contract.** All Neovim internals (autocmds, vim.api.*, treesitter, filetypes, options, highlights) are wrapped in OOP classes. Code that builds features should never touch raw Neovim APIs directly — use `Buffer`, `Window`, `LspManager`, `Treesitter`, `Shell`, etc.

2. **No Neovim trivia leaks out.** A contributor should not need to know what an `autocmd` is, what `vim.bo` vs `vim.wo` means, or how `vim.schedule` works. The abstraction handles it.

3. **Minimize dependencies.** Every plugin is a liability. We started at 43 plugins, we're at 7, and the north star is fewer. When a plugin can be replaced by an extension (a few hundred lines of Lua using our abstractions), replace it. 36 plugins have already been absorbed this way.

4. **Extensions over plugins.** New features are built as `Extension` subclasses with a lifecycle (`on_register`), not as plugin configs. Extensions get commands, keymaps, hooks, toggles, and notifications through a clean context object.

5. **Diamond architecture — slots + adapters.** The IDE singleton is ONLY core infrastructure: subsystem registries (buffers, windows, lsp, config, theme, keys, fs, shell, text, icons), the extension system, and event wiring. Everything else is an extension that plugs into slots:
   - `ctx:command()` — register a user command
   - `ctx:keymap()` — register a keybinding
   - `ctx:hook()` — subscribe to an autocmd
   - `ctx:toggle()` — register a config toggle (planned)
   - `ctx:notify()` — show a notification
   - `Buffer.add_context_provider()` — add context menu items
   
   **Core (stays in IDE singleton):** Buffer, Window, BufferList, WindowList, LspManager, KeyManager, UI, ConfigManager, ThemeManager, Treesitter, Git, QuickFix, Marks, Text, IconDB, FileSystem, Shell, Extension registry, EventEmitter.
   
   **Extensions (55 registered in IDE:_register_extensions):** notifications, statusline, git_signs, autotag, icon_picker, markdown_preview, ts_comments, ts_error_translator, indent_guides, jump, folding, desktop, window_chrome, main_menu, command_palette, buffer_keymaps, editing_keymaps, debug_keymaps, lsp_keymaps, search_keymaps, quickfix_keymaps, file_operations, file_safety, file_palette, buffer_picker, diagnostics_panel, panels, test_runner, feature_toggles, context_menus, ui_select, completion, snippets, spelling, notes, terminal, lazygit, tmux_integration, session_persistence, format_on_save, lint_on_change, find_replace, cursor_effects, editor_defaults, status_column, mark_signs, message_filter, shell_commands, turbovision_theme, and more.

6. **Toolkit components are shared UI primitives.** Panel, List, Picker, ContextMenu, ToggleMenu, Toast, KeyHint, StyledLine, StyledText, Icon, StatusBar, TabBar, WinBar — these live in `lua/ide/toolkit/` and are used by any extension. No UI code should be inlined in extensions — extract reusable components into the toolkit.

## Project Structure

```
init.lua                   -- Entry point: init -> options -> lazy -> IDE
lua/init.lua               -- Stdlib: Class(), xassert(), table.*, hash(), memoize()
lua/options.lua            -- vim.opt settings
lua/ide/
  init.lua                 -- IDE singleton + boot
  Buffer.lua               -- Buffer abstraction (format, lint, LSP, diagnostics)
  BufferAST.lua            -- Treesitter AST queries per buffer
  BufferGit.lua            -- Per-buffer git diff info
  BufferLSP.lua            -- Per-buffer LSP client management
  BufferList.lua           -- Buffer collection with lifecycle
  Window.lua / WindowList.lua
  FramedWindow.lua         -- MDI child window with TurboVision borders
  LspManager.lua / LspServer.lua
  Treesitter.lua           -- Syntax tree abstraction
  Git.lua                  -- Git operations
  Extension.lua            -- Extension base class
  EventEmitter.lua         -- on/off/emit mixin
  ActionRegistry.lua       -- Named action system
  FileSystem.lua           -- File ops (scan, read, write, relative_path)
  Shell.lua                -- Async command execution
  ConfigManager.lua        -- Settings, toggles, buffer options
  ThemeManager.lua         -- Colorscheme and highlights
  SessionManager.lua       -- Session save/restore
  DebugManager.lua         -- DAP debugging
  QuickFix.lua             -- Quickfix/location list
  Marks.lua                -- Mark management
  DiagnosticSet.lua        -- Buffer-scoped diagnostic queries
  Command.lua              -- User command builder
  Dispatch.lua             -- Renderer dispatch (statusline, tabline)
  Timer.lua                -- Periodic/delayed execution
  Highlight.lua            -- Highlight group builder
  Notify.lua               -- Notifications
  UI.lua                   -- Unified UI (notify, finder, tree)
  Finder.lua               -- Telescope internalized
  FileTree.lua             -- File explorer internalized
  FuzzyScorer.lua          -- Fuzzy matching (fzf-native)
  KeyManager.lua           -- Keymaps + key hints
  Mouse.lua                -- Right-click context menu
  Position.lua             -- Cursor position value object
  IconDB.lua               -- File icon database (core)
  Text.lua                 -- String/char utilities
  Project.lua              -- Project detection (root, type)
  FormatterRunner.lua      -- Format pipeline
  LinterRunner.lua         -- Lint pipeline
  toolkit/                 -- 44 shared UI components
    Panel.lua, List.lua, Picker.lua, Canvas.lua,
    ContextMenu.lua, ToggleMenu.lua, InfoPanel.lua,
    StatusBar.lua, TabBar.lua, WinBar.lua,
    StyledLine.lua, StyledText.lua, Icon.lua,
    Toast.lua, KeyHint.lua, Dialog.lua, MessageBox.lua,
    MenuBar.lua, MenuDropdown.lua, MenuItem.lua,
    SearchableList.lua, FilePicker.lua, GrepPicker.lua,
    SelectPicker.lua, ManagedFloat.lua, Shadow.lua,
    Splitter.lua, TabControl.lua, TreeView.lua, TreeNode.lua,
    Button.lua, InputField.lua, Checkbox.lua, RadioGroup.lua,
    ComboBox.lua, ListBox.lua, ProgressBar.lua, Tooltip.lua,
    VirtualText.lua, QuickFix.lua,
    hooks.lua, component.lua  -- React-like function component runtime
  extensions/              -- 56 feature extensions (diamond architecture)
  test.lua                 -- Base test suite (128 tests)
  test_extended.lua        -- Extended tests (1057 tests)
  test_visual.lua          -- Visual snapshot tests (51 tests, tmux-based)
  test_fixtures/           -- Fixture projects (Go, TS, Python, broken Lua)
```

### Legacy Layer

The legacy `_G.ide` (lowercase) system has been fully migrated to `_G.IDE` (uppercase). No legacy references remain.

## How to Work in This Codebase

**When building a new feature:**
- Create an `Extension` subclass, not a loose script.
- Use IDE classes (`IDE.buffers`, `IDE.lsp`, `IDE.ui`, etc.), never raw `vim.*` calls.
- Register through `IDE:register_extension()`.

**When modifying existing behavior:**
- Find the relevant class in `lua/ide/`. Change the abstraction, not the call sites.
- If a Neovim API is used directly somewhere, that's a bug — wrap it first.

**When removing a plugin:**
- Write an extension that replaces its functionality using IDE abstractions.
- Add tests. Remove the plugin config from `lua/plugins/`.

**Extension template:**
```lua
local MyExt = Class('MyExt', IDE.Extension)
function MyExt:init() IDE.Extension.init(self, 'MyExt') end
function MyExt:on_register(ctx)
    ctx:command('MyCmd', function() ... end)
    ctx:keymap('n', '<leader>x', function() ... end)
    ctx:hook('BufWritePre', function() ... end)
    ctx:notify('Extension loaded!')
end
IDE:register_extension(MyExt())
```

## Testing

There are **1273 tests** across three suites. All tests run inside Neovim itself.

### Unit + Integration Tests (1222 tests)

Run from inside Neovim:
```vim
:IDETest
```
This executes `ide/test.lua` (128 base) + `ide/test_extended.lua` (1094 extended). Tests cover class instantiation, buffer lifecycle, LSP integration, diagnostics, filesystem ops, event emitter, config manager, command builder, toolkit components, extensions, and more.

Test files use fixture projects in `ide/test_fixtures/` (Go, TypeScript, Python, intentionally broken Lua).

### Visual Snapshot Tests (51 tests, tmux required)

These tests capture what the user actually sees on screen. They require a **tmux session**.

**How to run:**
```vim
:lua require('ide.test_visual').run()
```

**How they work:**
1. Tests run `tmux capture-pane` to grab the terminal output (plain text and ANSI color).
2. They assert on statusline content, tabline, winbar, error absence, fold markers, syntax highlighting (RGB codes in ANSI output), panel rendering, and visual artifact detection.
3. Snapshots are saved to `/tmp/ide_visual_snapshots/` for debugging failures.
4. Results are saved to `/tmp/ide_visual_results.txt`.

**What they verify:**
- Statusline shows mode, LSP client name, AI indicator
- Tabline and winbar have content
- No error notifications on startup or file switch
- No buffer corruption (command text leaking into buffer)
- Hover popup opens and closes cleanly
- Rapid file switching leaves no artifacts
- Fold markers appear/disappear correctly
- Syntax highlighting produces RGB color codes
- IDE panels render with borders and close cleanly
- Comment toggle (gcc) works and undoes correctly

**Tmux requirement:** Visual tests check `vim.env.TMUX` and refuse to run outside tmux. To run them from the terminal:
```bash
tmux new-session -d -s test 'nvim'
tmux send-keys -t test ':lua require("ide.test_visual").run()' Enter
# Wait for completion, then:
cat /tmp/ide_visual_results.txt
```

### Running All Tests from Outside Neovim (via tmux)

To run the full suite non-interactively:
```bash
tmux new-session -d -s test 'nvim --headless +"IDETest" +"lua require(\"ide.test_visual\").run()" +"qa!"'
tmux send-keys -t test '' Enter
```
Or attach and run interactively — visual tests need a visible pane to capture.

## Current Plugins (7)

```
KEEP (infrastructure):
  dap, lazydev, lspconfig, mason, neotest, supermaven, treesitter

ABSORBED (36 plugins replaced by extensions):
  nvim-web-devicons → IconDB + file_icons database
  nvim-notify → notifications extension + Toast toolkit
  lualine → statusline extension + StatusBar/TabBar/WinBar toolkit
  gitsigns → git_signs extension
  which-key → KeyManager + KeyHint toolkit
  conform → FormatterRunner + format_on_save extension
  nvim-lint → LinterRunner + lint_on_change extension
  telescope → Finder + FilePicker/GrepPicker toolkit
  neo-tree → FileTree + TreeView toolkit
  noice → message_filter extension
  dap-ui, dap-go, dap-python, dap-vscode-js → DebugManager
  luasnip → snippets extension
  nvim-cmp → completion extension
  flash → jump extension
  indent-blankline → indent_guides extension
  Comment.nvim → ts_comments extension
  nvim-bqf → QuickFix toolkit
  nvim-ufo → folding extension
  dressing → ui_select extension
  tokyonight → turbovision_theme extension
  ... and more
```

## Known Issues

1. **LuaJIT `#` limitation** — `table.freeze()` proxy tables always report `#frozen == 0` because LuaJIT ignores `__len` for tables. Use `ipairs()` or `pairs()` to iterate frozen tables.

## Key Commands

| Command | What it does |
|---------|--------------|
| `:IDETest` | Run 1273-test suite (base + extended) |
| `:IDEStatus` | Buffer, project, LSP, diagnostics panel |
| `:IDELsp` | Per-client LSP status |
| `:IDEGit` | Branch + recent commits |
| `:IDEDiagnostics` | Floating diagnostic viewer |
| `:IDEQuickFix` | Floating quickfix viewer |
| `:IDEBuffers` | Buffer picker |
| `:IDEIcons` | Nerd font icon search (10,764 icons) |
| `:IDEPreview` | Toggle markdown preview |
| `:IDEExtensions` | List registered extensions |
| `:IDEOutline` | Document symbol outline (LSP/treesitter) |

## North Star

The end state is an IDE where the only plugins left are **infrastructure that cannot be replicated** — lazy.nvim (plugin loader), dap + dap-ui (debug protocol), mason (LSP/tool registry), treesitter (parser registry). Everything else — UI, keymaps, statusline, file explorer, git integration, notifications, fuzzy finding — is built from our own abstractions.

### Plugin Elimination Targets

```
ABSORB (remaining 7 plugins, candidates for replacement):
  neotest          → IDE.TestRunner extension (partially wrapped)
  supermaven       → IDE.Completion extension (partially wrapped)
  lspconfig        → absorb server configs into LspManager
  mason            — LSP/tool installer registry (hard to replace)
  dap              — debug adapter protocol (complex external protocol)

KEEP (irreplaceable infrastructure):
  lazy.nvim        — plugin loader (bootstraps everything)
  treesitter       — parser installer registry
  lazydev          — lua_ls type hints (dev-time only)
```

### UI Architecture

The toolkit is fully owned — no nui.nvim dependency. All UI primitives (floating windows, borders, input handling, layout, shadows, splitters) are built directly on Neovim's window API via ManagedFloat.

**React-like function component runtime** (`hooks.lua` + `component.lua`):
- **Core hooks**: `useState`, `useReducer`, `useMemo`, `useCallback`, `useEffect`, `useLayoutEffect`, `useRef`
- **Shared state**: `createContext` + `useContext` for cross-component state
- **IDE hooks**: `useKeymap`, `useAutoCmd`, `useToggle`, `useBuffer`, `useLsp`
- **Performance**: `batch()` for grouping state updates into single re-render
- **Composition**: `{ type = 'component', render = fn, props = {} }` VNode for nested components
- **Error boundaries**: component render errors show fallback UI instead of crashing
- **Converted components**: Picker, InfoPanel, ToggleMenu use function components for content rendering

### UX Inspiration Sources

- **LazyVim** (folke/LazyVim) — Best-in-class Neovim UX patterns. Study its UI components, status indicators, and interaction patterns. Absorb the good ideas as extensions using our abstractions.
- **folke's plugins** (lazy.nvim, noice.nvim, which-key.nvim, snacks.nvim) — Reference implementations for UI patterns we want to own.

### Configuration Target

One file — `lua/config.lua` — where all wiring uses IDE abstractions:
```lua
IDE.key_mappings:bind(IDE.Modes.normal, '<leader>w', IDE.Actions.save)
IDE.key_mappings:bind(IDE.Modes.normal, ']m', IDE.Actions.next_diagnostic)
IDE.options:set({ line_wrap = false, scroll_margin = 8 })
IDE.theme:apply('tokyonight-moon')
```
No `vim.keymap.set`, no `vim.opt`, no `vim.api.*` outside IDE class internals.

### Testing Standard

Every feature, extension, and abstraction must have:
- **Unit tests** — class instantiation, method behavior, edge cases, provable coverage
- **Integration tests** — cross-class interactions, LSP responses, buffer lifecycle
- **Visual E2E tests** — tmux pane capture **immediately after every operation**. Sending a keybinding is not enough — you must capture the pane right after to verify: no errors appeared, no UI artifacts, no broken layout, correct content rendered. A test that sends keys without capturing the visual result is incomplete.

## Target

nvim 0.12+ | Theme: Tokyo Night Moon | Startup: ~60ms | 0 errors at runtime
