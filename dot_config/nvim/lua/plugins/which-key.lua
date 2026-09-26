return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "modern",
    -- Named top-level <leader> groups -- previously undeclared, so which-key
    -- inferred labels purely from leaf `desc` strings. Only single-member
    -- bare leaves (<leader>e explorer, <leader>w save, <leader>?) are left
    -- unnamed here; a lone action doesn't need a group label.
    spec = {
      { "<leader>a", group = "AI" },
      { "<leader>b", group = "Buffer" },
      { "<leader>c", group = "Code" },
      { "<leader>d", group = "Debug" },
      { "<leader>f", group = "Find" },
      { "<leader>h", group = "Git Hunk" },
      { "<leader>n", group = "Notebook" },
      { "<leader>q", group = "Session" },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer local keymaps",
    },
  },
}
