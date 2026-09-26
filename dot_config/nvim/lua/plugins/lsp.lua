-- LSP configuration using Neovim's native vim.lsp.enable() / vim.lsp.config()
-- (0.11+), not nvim-lspconfig's older setup{} framework. nvim-lspconfig is
-- kept only as a data-only dependency: it ships the default lsp/<name>.lua
-- configs on its runtimepath, which vim.lsp.enable() picks up automatically.
--
-- A same-named sibling lsp/<name>.lua under .config/nvim/ (next to lua/,
-- not inside it) is Neovim's documented way to layer in extra config, but
-- it is NOT a reliable way to *override* a key nvim-lspconfig's own file
-- already sets: nvim_get_runtime_file() returns user config before plugin
-- files (~/.config/nvim precedes lazy-installed plugins on 'runtimepath'),
-- and the later file in that list wins per matching key when vim.lsp merges
-- them -- so the plugin's own value clobbers the user's, the opposite of
-- what "override" implies. Confirmed by hand for qmlls below: a sibling
-- file alone left `cmd` on nvim-lspconfig's default and the server never
-- started ("qmlls is not executable"). Use an explicit vim.lsp.config()
-- call instead for anything that must actually win.
--
-- All servers here are installed system-wide via pacman/paru, not
-- mason.nvim -- this project installs tooling repo -> AUR -> user-install,
-- consistent with the rest of this dotfiles repo.
return {
  "neovim/nvim-lspconfig",
  lazy = false,
  dependencies = { "b0o/schemastore.nvim" },
  config = function()
    -- This system's Qt6 (qt6-declarative, already a Quickshell dependency)
    -- installs the binary as `qmlls6`, not `qmlls` -- documented directly
    -- in nvim-lspconfig's own default lsp/qmlls.lua as the standard fix.
    vim.lsp.config("qmlls", { cmd = { "qmlls6" } })

    -- Schema-driven completion/validation for known JSON/YAML files
    -- (package.json, GitHub Actions workflows, etc.)
    vim.lsp.config("jsonls", {
      settings = {
        json = {
          schemas = require("schemastore").json.schemas(),
          validate = { enable = true },
        },
      },
    })
    vim.lsp.config("yamlls", {
      settings = {
        yaml = {
          schemaStore = { enable = false, url = "" },
          schemas = require("schemastore").yaml.schemas(),
        },
      },
    })

    vim.lsp.enable({
      "lua_ls",
      "bashls",
      "basedpyright",
      "ruff",
      "rust_analyzer",
      "gopls",
      "vtsls",
      "jsonls",
      "yamlls",
      "dockerls",
      "marksman",
      -- QML: this project's entire Quickshell shell (~9k lines) is QML.
      "qmlls",
    })

    vim.diagnostic.config({
      virtual_text = { spacing = 4, prefix = "●" },
      severity_sort = true,
      float = { border = "rounded" },
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "",
          [vim.diagnostic.severity.WARN] = "",
          [vim.diagnostic.severity.INFO] = "",
          [vim.diagnostic.severity.HINT] = "",
        },
      },
    })

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("xcloud-lsp-attach", { clear = true }),
      desc = "Buffer-local LSP keymaps",
      callback = function(args)
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
        end

        map("n", "gd", vim.lsp.buf.definition, "Goto definition")
        map("n", "gD", vim.lsp.buf.declaration, "Goto declaration")
        map("n", "gi", vim.lsp.buf.implementation, "Goto implementation")
        map("n", "gr", vim.lsp.buf.references, "Goto references")
        map("n", "K", vim.lsp.buf.hover, "Hover documentation")
        -- Rename/code-action/type-definition deliberately not remapped here --
        -- Neovim 0.11+'s own LspAttach defaults already provide grn/gra/grt,
        -- so a custom <leader>rn/<leader>ca/<leader>D would just duplicate them.
        map("n", "[d", function()
          vim.diagnostic.jump({ count = -1, float = true })
        end, "Previous diagnostic")
        map("n", "]d", function()
          vim.diagnostic.jump({ count = 1, float = true })
        end, "Next diagnostic")
      end,
    })
  end,
}
