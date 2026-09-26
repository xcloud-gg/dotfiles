-- General-purpose autocmds not tied to any one plugin.

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight on yank
autocmd("TextYankPost", {
  group = augroup("xcloud-highlight-yank", { clear = true }),
  desc = "Briefly highlight yanked text",
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Trim trailing whitespace on save
autocmd("BufWritePre", {
  group = augroup("xcloud-trim-whitespace", { clear = true }),
  desc = "Trim trailing whitespace on save",
  pattern = "*",
  callback = function()
    if not vim.bo.modifiable then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Restore cursor position when reopening a file
autocmd("BufReadPost", {
  group = augroup("xcloud-restore-cursor", { clear = true }),
  desc = "Restore cursor to last known position",
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Resize splits equally when the terminal/window is resized
autocmd("VimResized", {
  group = augroup("xcloud-resize-splits", { clear = true }),
  desc = "Keep splits equally sized on resize",
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})
