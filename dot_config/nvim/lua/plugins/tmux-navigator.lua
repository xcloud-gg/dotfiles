-- Seamless pane<->split navigation via unprefixed Ctrl-hjkl -- the tmux
-- side (dotfiles/tmux/.tmux.conf) uses this same plugin's own documented
-- is_vim detection script, so Ctrl-hjkl moves within Neovim splits, then
-- transparently extends to tmux panes at the edge, in either direction.
-- Replaces the plain <C-w>hjkl maps that used to live in keymaps.lua.
return {
  "christoomey/vim-tmux-navigator",
  lazy = false,
  keys = {
    { "<C-h>", "<cmd>TmuxNavigateLeft<CR>", desc = "Navigate left (tmux-aware)" },
    { "<C-j>", "<cmd>TmuxNavigateDown<CR>", desc = "Navigate down (tmux-aware)" },
    { "<C-k>", "<cmd>TmuxNavigateUp<CR>", desc = "Navigate up (tmux-aware)" },
    { "<C-l>", "<cmd>TmuxNavigateRight<CR>", desc = "Navigate right (tmux-aware)" },
  },
}
