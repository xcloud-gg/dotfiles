-- fzf-lua: fuzzy finder, replacing Telescope.
return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "FzfLua",
  keys = {
    { "<leader>ff", "<cmd>FzfLua files<CR>", desc = "Find files" },
    { "<leader>fg", "<cmd>FzfLua live_grep<CR>", desc = "Live grep" },
    { "<leader>fb", "<cmd>FzfLua buffers<CR>", desc = "Find buffers" },
    { "<leader>fh", "<cmd>FzfLua help_tags<CR>", desc = "Help tags" },
    { "<leader>fo", "<cmd>FzfLua oldfiles<CR>", desc = "Recent files" },
    { "<leader>fr", "<cmd>FzfLua resume<CR>", desc = "Resume last search" },
    { "<leader>fd", "<cmd>FzfLua diagnostics_document<CR>", desc = "Document diagnostics" },
    { "<leader>fs", "<cmd>FzfLua lsp_document_symbols<CR>", desc = "Document symbols" },
  },
  opts = {},
}
