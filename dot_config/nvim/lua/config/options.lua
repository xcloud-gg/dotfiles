-- Core vim.opt / vim.g settings.

local opt = vim.opt
local g = vim.g

-- Leader keys (must be set before plugins that map <leader>-prefixed keys)
g.mapleader = " "
g.maplocalleader = " "

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

-- Clipboard: use the system clipboard for all yank/delete/paste
opt.clipboard = "unnamedplus"

-- Splits open below/right, matching how you read a screen
opt.splitright = true
opt.splitbelow = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

-- UI
opt.signcolumn = "yes"
opt.termguicolors = true
opt.cursorline = true
opt.scrolloff = 8
opt.wrap = false
opt.showmode = false

-- Persistent undo
opt.undofile = true
opt.swapfile = false
opt.backup = false

-- Update/redraw behaviour that completion and LSP plugins rely on
opt.updatetime = 250
opt.timeoutlen = 300

-- Completion menu
opt.completeopt = { "menu", "menuone", "noselect" }

-- Misc QoL
opt.mouse = "a"
opt.confirm = true
