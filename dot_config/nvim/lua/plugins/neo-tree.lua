return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  keys = {
    { "\\", "<cmd>Neotree toggle<CR>", desc = "Toggle Neo-tree" },
    { "<leader>e", "<cmd>Neotree focus<CR>", desc = "Focus Neo-tree" },
  },
  opts = {
    close_if_last_window = true,
    popup_border_style = "rounded",
    filesystem = {
      filtered_items = {
        visible = false,
        hide_dotfiles = false,
        hide_gitignored = false,
      },
      follow_current_file = {
        enabled = true,
      },
      use_libuv_file_watcher = true,
    },
    window = {
      position = "left",
      width = 35,
      mappings = {
        ["<space>"] = "none",
      },
    },
    default_component_configs = {
      indent = {
        with_expanders = true,
      },
    },
  },
}
