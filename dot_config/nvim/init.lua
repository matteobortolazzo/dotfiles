-- Set leader key before lazy.nvim loads
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load configuration modules
require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
