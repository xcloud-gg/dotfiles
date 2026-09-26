-- conform.nvim: format-on-save via external formatter binaries (installed
-- system-wide, not via mason.nvim). lsp_format = "never" -- formatting is
-- always done by these formatters, never silently by whichever LSP server
-- happens to be attached.
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "never" })
      end,
      mode = { "n", "v" },
      desc = "Format buffer",
    },
  },
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      bash = { "shfmt" },
      sh = { "shfmt" },
      python = { "ruff_format" },
      rust = { "rustfmt" },
      go = { "gofmt" },
      qml = { "qmlformat" },
      json = { "prettier" },
      jsonc = { "prettier" },
      yaml = { "prettier" },
      markdown = { "prettier" },
    },
    format_on_save = {
      lsp_format = "never",
      timeout_ms = 1000,
    },
  },
}
