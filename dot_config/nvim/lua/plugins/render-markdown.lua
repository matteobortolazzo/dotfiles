return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  ft = { "markdown" },
  opts = {
    heading = {
      enabled = true,
      icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " },
    },
    code = {
      enabled = true,
      style = "full",
      border = "thin",
    },
    bullet = {
      enabled = true,
    },
    checkbox = {
      enabled = true,
    },
    dash = {
      enabled = true,
      icon = "─",
    },
    quote = {
      enabled = true,
    },
    link = {
      enabled = true,
      icon = " ",
    },
    win_options = {
      conceallevel = { rendered = 2 },
    },
  },
}
