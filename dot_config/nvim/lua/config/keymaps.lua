-- Non-LSP keymaps. LSP-specific keymaps (goto-def, hover, diagnostic nav) are
-- set buffer-locally in the LspAttach autocmd in lua/plugins/lsp.lua, not
-- here. Rename/code-action/type-definition are deliberately unmapped
-- anywhere -- Neovim 0.11+'s own LspAttach defaults (grn/gra/grt) already
-- cover them.

local map = vim.keymap.set

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Window navigation: <C-hjkl> is handled by vim-tmux-navigator
-- (lua/plugins/tmux-navigator.lua) instead of a plain <C-w>hjkl map here --
-- it seamlessly extends the same keys out to tmux panes when the split
-- being moved into doesn't exist, rather than only moving within Neovim.

-- Window resizing
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })

-- Buffer navigation
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- Move lines up/down in visual mode
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Keep cursor centered when scrolling/joining
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down, keep cursor centered" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up, keep cursor centered" })
map("n", "J", "mzJ`z", { desc = "Join line, keep cursor position" })

-- Indent/outdent and stay in visual mode
map("v", "<", "<gv", { desc = "Outdent selection" })
map("v", ">", ">gv", { desc = "Indent selection" })

-- Diagnostics float -- grouped under the Debug prefix (<leader>d) since it's
-- debug-adjacent, and not LSP-exclusive (nvim-lint produces diagnostics too),
-- so it doesn't belong in lsp.lua's buffer-local LspAttach scope.
map("n", "<leader>dd", vim.diagnostic.open_float, { desc = "Show line diagnostics" })

-- Save
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Save file" })
