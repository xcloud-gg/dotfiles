-- Talks to Claude via the claude_code ACP adapter (bridge binary:
-- `claude-agent-acp`, installed to ~/.local/bin -- no AUR package exists for
-- it, and npm -g into /usr is forbidden on this machine, so it's installed
-- with `npm install --prefix ~/.local -g
-- @agentclientprotocol/claude-agent-acp`).
--
-- Live-tested and found NOT to reuse the machine's already-logged-in `claude`
-- CLI session: it needs its own CLAUDE_CODE_OAUTH_TOKEN in the environment
-- (the adapter reads that exact env var name by default, no config needed
-- here) or every chat turn fails with "401 Invalid bearer token". Generate
-- one with `claude setup-token` (interactive, browser-confirmed) and export
-- CLAUDE_CODE_OAUTH_TOKEN from your shell profile -- not done here since it's
-- a per-user secret, not something to commit.
return {
  "olimorris/codecompanion.nvim",
  cmd = { "CodeCompanionChat", "CodeCompanionActions", "CodeCompanionCmd" },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {
    strategies = {
      chat = { adapter = "claude_code" },
      inline = { adapter = "claude_code" },
    },
  },
  keys = {
    { "<leader>ac", "<cmd>CodeCompanionChat Toggle<CR>", mode = { "n", "v" }, desc = "Toggle AI chat" },
    { "<leader>aa", "<cmd>CodeCompanionActions<CR>", mode = { "n", "v" }, desc = "AI actions" },
  },
}
