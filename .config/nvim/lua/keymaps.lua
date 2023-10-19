-- Disable some sequences
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.keymap.set("n", "<BS>", "<Nop>", { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { desc = "Move cursor up", expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { desc = "Move cursor down", expr = true, silent = true })

-- Better normal mode navigation
vim.keymap.set({ "n", "x" }, "gg",
    function() if vim.v.count > 0 then vim.cmd("normal! " .. vim.v.count .. "gg") else vim.cmd "normal! gg0" end end,
    { desc = "Start of buffer" }
)

vim.keymap.set({ "n", "x" }, "G", function() vim.cmd "normal! G$" end, { desc = "End of buffer" })

-- move selection up/down
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection downward' })
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection upward' })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.set({ "n", "x", "o" }, "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set({ "n", "x", "o" }, "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })

-- Add undo break-points
vim.keymap.set("i", ",", ",<c-g>u")
vim.keymap.set("i", ".", ".<c-g>u")
vim.keymap.set("i", ";", ";<c-g>u")

-- Redo
vim.keymap.set("n", "<C-r>", "Nzzzv", { desc = "Redo", remap = true })

-- Some editor mappings
vim.keymap.set("i", "<C-BS>", "<C-w>", { desc = "Delete word" })
vim.keymap.set("i", "<Tab>", "<C-T>", { desc = "Indent", })
vim.keymap.set("i", "<S-Tab>", "<C-D>", { desc = "Unindent" })

-- Disable the annoying yank on chnage
vim.keymap.set({ "n", "x" }, "c", [["_c]], { desc = "Change" })
vim.keymap.set({ "n", "x" }, "C", [["_C]], { desc = "Change" })
vim.keymap.set("x", "p", "P", { desc = "Paste" })
vim.keymap.set("x", "P", "p", { desc = "Yank & paste" })

-- window navigation
vim.keymap.set('n', '<A-Tab>', "<C-W>w", { desc = 'Switch window' })
vim.keymap.set('n', '<A-Left>', "<cmd>wincmd h<cr>", { desc = 'Go to left window' })
vim.keymap.set('n', '<A-Right>', "<cmd>wincmd l<cr>", { desc = 'Go to right window' })
vim.keymap.set('n', '<A-Down>', "<cmd>wincmd j<cr>", { desc = 'Go to window below' })
vim.keymap.set('n', '<A-Up>', "<cmd>wincmd k<cr>", { desc = 'Go to window above' })
vim.keymap.set("n", "\\", "<C-W>s", { desc = "Split window below", remap = true })
vim.keymap.set("n", "|", "<C-W>v", { desc = "Split window right", remap = true })

-- terminal mappings
vim.keymap.set("t", "<esc><esc>", "<c-\\><c-n>", { desc = "Enter normal mode" })

-- buffer management
vim.keymap.set("n", "<leader><leader>", function() pcall(vim.cmd, "e #") end, { desc = "Switch buffer", silent = true })
vim.keymap.set("n", "<leader>bw", "<cmd>w<cr>", { desc = "Save buffer" })
vim.keymap.set("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
vim.keymap.set("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- clear search with <esc>
vim.keymap.set({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and clear highlight" })

-- better indenting
vim.keymap.set("x", "<", "<gv", { desc = "Indent selection" })
vim.keymap.set("x", ">", ">gv", { desc = "Unindent selection" })

vim.keymap.set("x", "<Tab>", ">gv", { desc = "Indent selection" })
vim.keymap.set("x", "<S-Tab>", ">gv", { desc = "Unindent selection" })

-- tabs
vim.keymap.set("n", "]t", "<cmd>tabnext<cr>", { desc = "Next tab" })
vim.keymap.set("n", "[t", "<cmd>tabprevious<cr>", { desc = "Previous tab" })

-- Some useful keymaps for me
vim.keymap.set("x", "<BS>", "d", { desc = "Delete selection", remap = true })
