-- xCloud Neovim configuration
--
-- Entry point: just wires up the config/ modules and hands off to lazy.nvim
-- for plugin management. Plugin specs live under lua/plugins/ and are loaded
-- via `import = "plugins"` in lua/config/lazy.lua.

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
