return {
  "folke/zen-mode.nvim",
  -- cmd so <leader>mz (set in config/prose.lua) can trigger the load too.
  cmd = "ZenMode",
  keys = {
    { "<leader>z", "<cmd>ZenMode<CR>", desc = "Zen mode" },
  },
  opts = {
    window = {
      backdrop = 0.95,
      width = 120,
      height = 1,
      options = {
        signcolumn = "no",
        number = false,
        relativenumber = false,
        cursorline = false,
      },
    },
    plugins = {
      options = {
        enabled = true,
        ruler = false,
        showcmd = false,
      },
      gitsigns = { enabled = false },
    },
  },
}
