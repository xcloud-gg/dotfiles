-- nvim-lint: async linters run on save/insert-leave, complementing the LSP
-- diagnostics with tools that aren't themselves language servers.
return {
  "mfussenegger/nvim-lint",
  event = { "BufWritePost", "BufReadPost", "InsertLeave" },
  config = function()
    local lint = require("lint")

    lint.linters_by_ft = {
      sh = { "shellcheck" },
      bash = { "shellcheck" },
      python = { "ruff" },
      yaml = { "yamllint" },
      dockerfile = { "hadolint" },
    }

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      group = vim.api.nvim_create_augroup("xcloud-lint", { clear = true }),
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}
