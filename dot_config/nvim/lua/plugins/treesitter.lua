return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup()

    local parsers = {
      "bash",
      "c",
      "c_sharp",
      "css",
      "html",
      "javascript",
      "json",
      "lua",
      "luadoc",
      "markdown",
      "markdown_inline",
      "python",
      "typescript",
      "vim",
      "vimdoc",
      "yaml",
    }
    require("nvim-treesitter").install(parsers)

    -- markdown_inline has no buffer filetype (injection-only).
    local filetypes = {
      "bash",
      "c",
      "cs",
      "css",
      "html",
      "javascript",
      "json",
      "lua",
      "markdown",
      "python",
      "typescript",
      "vim",
      "help",
      "yaml",
    }
    vim.api.nvim_create_autocmd("FileType", {
      pattern = filetypes,
      callback = function()
        pcall(vim.treesitter.start)
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo.foldmethod = "expr"
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
