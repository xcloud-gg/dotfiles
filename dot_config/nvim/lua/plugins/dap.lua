-- nvim-dap: lazy-loaded (only cmd/keys below trigger install/load), so it
-- costs nothing until a debug session is actually started. Adapters use
-- system-installed binaries (python-debugpy via pacman), same convention
-- as the rest of this repo's LSP/formatter/linter tooling -- no mason.nvim.
--
-- Scoped to Python and Lua for now: debugpy is a real pacman package, and
-- osv debugs Neovim's own Lua state with no external binary at all. Rust/
-- Go/Bash adapters (codelldb, delve, bashdb) are real options too but
-- pulled in only if actually needed later -- codelldb and bashdb are
-- AUR-only and this repo's installer has no AUR-bootstrapping step (see
-- README's Known Limitations), so adding them speculatively would mean
-- shipping a config that silently doesn't work on a fresh install.
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
      "mfussenegger/nvim-dap-python",
      "jbyuki/one-small-step-for-vimkind",
    },
    cmd = { "DapToggleBreakpoint", "DapContinue" },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Debug: continue/start" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Debug: step over" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Debug: step into" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Debug: step out" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Debug: toggle REPL" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Debug: toggle UI" },
      {
        "<leader>dL",
        function() require("osv").launch({ port = 8086 }) end,
        desc = "Debug: launch Lua server (osv)",
      },
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")

      dapui.setup()
      require("nvim-dap-virtual-text").setup()
      require("dap-python").setup("/usr/bin/python3")

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn" })
    end,
  },
}
