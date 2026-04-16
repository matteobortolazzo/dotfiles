return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false,
    workspaces = {
      {
        name = "vault",
        path = "~/Repos/vault",
      },
    },
    daily_notes = {
      enabled = true,
      folder = "daily",
      date_format = "%Y-%m-%d",
    },
    templates = {
      folder = "templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
    },
    completion = {
      nvim_cmp = false,
      blink = true,
      min_chars = 2,
    },
    picker = {
      name = "telescope.nvim",
    },
    ui = { enable = false },
    attachments = {
      folder = "assets/imgs",
    },
  },
  keys = {
    { "<leader>oo", "<cmd>Obsidian quick_switch<cr>",    desc = "Obsidian: quick switch" },
    { "<leader>on", "<cmd>Obsidian new<cr>",             desc = "Obsidian: new note" },
    { "<leader>od", "<cmd>Obsidian today<cr>",           desc = "Obsidian: today" },
    { "<leader>oy", "<cmd>Obsidian yesterday<cr>",       desc = "Obsidian: yesterday" },
    { "<leader>ot", "<cmd>Obsidian tomorrow<cr>",        desc = "Obsidian: tomorrow" },
    { "<leader>os", "<cmd>Obsidian search<cr>",          desc = "Obsidian: search" },
    { "<leader>ob", "<cmd>Obsidian backlinks<cr>",       desc = "Obsidian: backlinks" },
    { "<leader>og", "<cmd>Obsidian tags<cr>",            desc = "Obsidian: tags" },
    { "<leader>or", "<cmd>Obsidian rename<cr>",          desc = "Obsidian: rename" },
    { "<leader>op", "<cmd>Obsidian paste_img<cr>",       desc = "Obsidian: paste image" },
    { "<leader>oc", "<cmd>Obsidian toggle_checkbox<cr>", desc = "Obsidian: toggle checkbox" },
    { "<leader>ol", "<cmd>Obsidian link<cr>",            mode = "v", desc = "Obsidian: link selection" },
    { "<leader>oN", "<cmd>Obsidian link_new<cr>",        mode = "v", desc = "Obsidian: new note from selection" },
  },
}
