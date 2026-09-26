-- Notebook: obsidian-nvim/obsidian.nvim (community-maintained fork of the
-- archived epwalsh/obsidian.nvim). Plain markdown, no proprietary format --
-- chosen over telekasten.nvim (hard-depends on telescope, which this repo
-- deliberately replaced with fzf-lua everywhere else, see finder.lua) and
-- over neorg (own .norg format, wrong fit for a small personal vault). Its
-- native multi-workspace support maps directly onto this rice's two vaults:
-- a shared notebook at /opt/docs (group-writable, both accounts) and a
-- per-user one at ~/.docs.
return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
  cmd = { "Obsidian" },
  keys = {
    { "<leader>no", "<cmd>Obsidian quick_switch<cr>", desc = "Notebook: open note" },
    { "<leader>nf", "<cmd>Obsidian search<cr>", desc = "Notebook: search notes" },
    { "<leader>nn", "<cmd>Obsidian new<cr>", desc = "Notebook: new note" },
    { "<leader>nt", "<cmd>Obsidian today<cr>", desc = "Notebook: today's daily note" },
    { "<leader>nb", "<cmd>Obsidian backlinks<cr>", desc = "Notebook: show backlinks" },
    { "<leader>nw", "<cmd>Obsidian workspace<cr>", desc = "Notebook: switch workspace" },
  },
  -- obsidian.nvim's UI module wants conceallevel >= 1 to render wikilinks;
  -- scoped to markdown buffers only rather than touching the global option.
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = function()
        vim.opt_local.conceallevel = 2
      end,
    })
  end,
  opts = {
    legacy_commands = false,
    workspaces = {
      { name = "personal", path = "~/.docs" },
      { name = "shared", path = "/opt/docs" },
    },
    picker = { name = "fzf-lua" },
    daily_notes = {
      folder = "daily",
      date_format = "%Y-%m-%d",
    },
    -- Default hl_groups ship hardcoded hex, disconnected from both
    -- catppuccin and the live matugen palette. These link instead to
    -- groups matugen.nvim's `treesitter` integration actually re-colors on
    -- wallpaper change (confirmed by reading
    -- ~/.local/share/nvim/lazy/matugen.nvim/lua/matugen_colorscheme/highlights/treesitter.lua),
    -- so checkbox/tag/link colors stay in sync with the rest of the rice.
    -- ObsidianHighlightText links to PmenuSel: matugen sets no dedicated
    -- search/highlight background group, so this is the closest live-themed
    -- bg+fg pair available.
    ui = {
      enable = true,
      hl_groups = {
        ObsidianTodo = { link = "@comment.todo" },
        ObsidianDone = { link = "@comment.note" },
        ObsidianRightArrow = { link = "@comment.warning" },
        ObsidianTilde = { link = "@markup.strikethrough" },
        ObsidianImportant = { link = "@comment.error" },
        ObsidianBullet = { link = "@markup.list" },
        ObsidianRefText = { link = "@markup.link" },
        ObsidianExtLinkIcon = { link = "@markup.link.url" },
        ObsidianTag = { link = "@tag" },
        ObsidianBlockID = { link = "@markup.raw" },
        ObsidianHighlightText = { link = "PmenuSel" },
      },
    },
  },
}
