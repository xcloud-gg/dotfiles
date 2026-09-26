-- nvim-treesitter, `main` branch: the rewritten API (no more
-- ensure_installed/setup{} table -- parsers are installed with
-- :TSInstall / require("nvim-treesitter").install(), and highlighting is
-- enabled per-buffer via the FileType autocmd below). The old `master`
-- branch is archived upstream.
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false,
  config = function()
    local parsers = {
      "lua",
      "vim",
      "vimdoc",
      "bash",
      "python",
      "rust",
      "go",
      "gomod",
      "typescript",
      "javascript",
      "json",
      "yaml",
      "dockerfile",
      "markdown",
      "markdown_inline",
      "query",
      "qmljs", -- this project's Quickshell shell is ~9k lines of QML
    }

    require("nvim-treesitter").install(parsers)

    -- Start highlighting for any filetype that has an installed parser;
    -- pcall covers filetypes with no matching parser (the pattern is left
    -- unrestricted since treesitter parser names and vim filetype names
    -- don't map 1:1, e.g. the "vimdoc" parser backs the "help" filetype).
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("xcloud-treesitter-highlight", { clear = true }),
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })
  end,
}
