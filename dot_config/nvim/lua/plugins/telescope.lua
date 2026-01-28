return {
  "nvim-telescope/telescope.nvim",
  tag = "0.1.8",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
      cond = function()
        return vim.fn.executable("make") == 1
      end,
    },
  },
  keys = {
    -- Find files
    { "<leader>sf", "<cmd>Telescope find_files<CR>", desc = "Find files" },
    { "<leader>sg", "<cmd>Telescope live_grep<CR>", desc = "Grep in files" },
    { "<leader>s.", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
    { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search in buffer" },

    -- Git
    { "<leader>gf", "<cmd>Telescope git_files<CR>", desc = "Git files" },
    { "<leader>gc", "<cmd>Telescope git_commits<CR>", desc = "Git commits" },
    { "<leader>gs", "<cmd>Telescope git_status<CR>", desc = "Git status" },

    -- LSP
    { "<leader>sd", "<cmd>Telescope diagnostics<CR>", desc = "Diagnostics" },
    { "<leader>ss", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Document symbols" },
    { "<leader>sS", "<cmd>Telescope lsp_workspace_symbols<CR>", desc = "Workspace symbols" },

    -- Misc
    { "<leader>sb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
    { "<leader>sh", "<cmd>Telescope help_tags<CR>", desc = "Help tags" },
    { "<leader>sk", "<cmd>Telescope keymaps<CR>", desc = "Keymaps" },
    { "<leader>sr", "<cmd>Telescope resume<CR>", desc = "Resume last search" },
  },
  opts = {
    defaults = {
      prompt_prefix = " ",
      selection_caret = " ",
      path_display = { "truncate" },
      sorting_strategy = "ascending",
      layout_config = {
        horizontal = {
          prompt_position = "top",
          preview_width = 0.55,
        },
        width = 0.87,
        height = 0.80,
      },
    },
    pickers = {
      find_files = {
        hidden = true,
      },
    },
  },
  config = function(_, opts)
    local telescope = require("telescope")
    telescope.setup(opts)
    pcall(telescope.load_extension, "fzf")
  end,
}
