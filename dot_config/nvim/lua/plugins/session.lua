-- Session persistence: save-on-exit, restore-on-demand. Same author as
-- snacks.nvim (already used here) and the same minimal-API philosophy as
-- the rest of this config -- parallels tmux-resurrect/tmux-continuum
-- (dotfiles/tmux/.tmux.conf) on the shell side of a daily-driver setup.
return {
  "folke/persistence.nvim",
  event = "BufReadPre",
  opts = {},
  keys = {
    {
      "<leader>qs",
      function()
        require("persistence").load()
      end,
      desc = "Restore session for this dir",
    },
    {
      "<leader>ql",
      function()
        require("persistence").load({ last = true })
      end,
      desc = "Restore last session",
    },
    {
      "<leader>qd",
      function()
        require("persistence").stop()
      end,
      desc = "Don't save current session on exit",
    },
  },
}
