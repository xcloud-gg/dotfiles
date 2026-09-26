-- catppuccin/nvim: first-class highlight groups for every other plugin in
-- this config (blink.cmp, fzf-lua, snacks.nvim, lualine, gitsigns,
-- which-key, ...), and easily swappable later without touching anything
-- else.
return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  lazy = false,
  opts = {
    flavour = "mocha",
    integrations = {
      blink_cmp = true,
      gitsigns = true,
      lualine = true,
      snacks = true,
      which_key = true,
      treesitter = true,
      native_lsp = {
        enabled = true,
      },
    },
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
  end,
}
