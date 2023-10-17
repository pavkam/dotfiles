-- Keymaps for a better life

-- Disable space
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- move selection up/down
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move Selection Downward' })
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move Selection Upward' })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.set("n", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set("n", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
vim.keymap.set("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
vim.keymap.set("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })

-- Add undo break-points
vim.keymap.set("i", ",", ",<c-g>u")
vim.keymap.set("i", ".", ".<c-g>u")
vim.keymap.set("i", ";", ";<c-g>u")

vim.keymap.set('n', '<C-r>', "Nzzzv", { desc = 'Redo', remap = true })

-- window navigation
vim.keymap.set('n', '<A-Tab>', "<C-W>w", { desc = 'Switch window' })
vim.keymap.set('n', '<A-Left>', "<cmd>wincmd h<cr>", { desc = 'Go to Left Window' })
vim.keymap.set('n', '<A-Right>', "<cmd>wincmd l<cr>", { desc = 'Go to Right Window' })
vim.keymap.set('n', '<A-Down>', "<cmd>wincmd j<cr>", { desc = 'Go to Down Window' })
vim.keymap.set('n', '<A-Up>', "<cmd>wincmd k<cr>", { desc = 'Go to Up Window' })
vim.keymap.set("n", "\\", "<C-W>s", { desc = "Split window below", remap = true })
vim.keymap.set("n", "|", "<C-W>v", { desc = "Split window right", remap = true })

-- terminal mappings
vim.keymap.set("t", "<esc><esc>", "<c-\\><c-n>", { desc = "Enter Normal Mode" })

-- buffer management
vim.keymap.set("n", "<leader><leader>", function() pcall(vim.cmd, "e #") end, { desc = "Switch to Other Buffer", silent = true })
vim.keymap.set("n", "<leader>bw", "<cmd>w<cr>", { desc = "Save Buffer" })
vim.keymap.set("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous Buffer" })
vim.keymap.set("n", "]b", "<cmd>bnext<cr>", { desc = "Next Buffer" })

-- clear search with <esc>
vim.keymap.set({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and Clear Highlight" })

-- better indenting
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- tabs
vim.keymap.set("n", "]t", "<cmd>tabnext<cr>", { desc = "Next Tab" })
vim.keymap.set("n", "[t", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })

-- Some useful keymaps for me
vim.keymap.set("v", "<BS>", "d", { desc = "Delete Selection" })
