return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    plugins = {
      marks = true,
      registers = true,
      spelling = {
        enabled = true,
        suggestions = 20,
      },
    },
    win = {
      border = "rounded",
    },
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)

    -- Register group names
    wk.add({
      { "<leader>g", group = "git" },
      { "<leader>h", group = "hunk" },
      { "<leader>s", group = "search" },
      { "<leader>t", group = "toggle" },
      { "gr", group = "goto" },
    })
  end,
}
