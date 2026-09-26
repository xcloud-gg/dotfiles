-- Dynamic, wallpaper-driven colorscheme: points directly at the same
-- ~/.config/xcloud/colors/colors.json that kitty/waybar/rofi/gtk and the
-- Quickshell shell's own Theme.qml all already read (confirmed identical
-- property names -- background/primary/on_surface/etc. -- no new matugen
-- template needed here, same as the Quickshell shell theming fix).
--
-- Layers on top of catppuccin rather than replacing it outright: catppuccin
-- stays loaded first so its blink_cmp/gitsigns/lualine/which_key/treesitter
-- integrations keep working, and matugen.nvim's own highlight overlay
-- (base/treesitter/cmp/gitsigns) applies the live Material palette on top.
return {
  "Ssnibles/matugen.nvim",
  lazy = false,
  priority = 999, -- after catppuccin (priority 1000), so this overlays it
  opts = {
    file = vim.fn.expand("~/.config/xcloud/colors/colors.json"),
    watch = true, -- live-reload when matugen regenerates it on wallpaper change
    plugins = {
      base = true,
      treesitter = true,
      cmp = true,
      gitsigns = true,
      miscellaneous = true,
    },
  },
}
