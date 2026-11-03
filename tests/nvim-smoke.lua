-- Run with the repository's config and plugins in isolated XDG directories.
local errors = {}
local notify = vim.notify
vim.notify = function(msg, level, opts)
  if level == vim.log.levels.ERROR then
    errors[#errors + 1] = tostring(msg)
  end
  notify(msg, level, opts)
end

require("lazy").load({ plugins = {
  "nvim-lspconfig", "blink.cmp", "conform.nvim", "telescope.nvim",
  "neo-tree.nvim", "render-markdown.nvim", "which-key.nvim", "zen-mode.nvim",
} })

assert(vim.lsp.config.lua_ls.settings.Lua.diagnostics.globals[1] == "vim")
assert(vim.lsp.config.lua_ls.capabilities.textDocument.completion.completionItem.snippetSupport)
assert(require("conform").formatters_by_ft.lua[1] == "stylua")
assert(require("telescope").extensions.fzf)

local treesitter = require("nvim-treesitter")
treesitter.install({ "bash", "lua", "go", "gomod", "javascript", "tsx", "markdown" }):wait(120000)
for _, ft in ipairs({ "sh", "lua", "go", "gomod", "javascriptreact", "typescriptreact", "markdown" }) do
  vim.cmd.enew()
  vim.bo.filetype = ft
  assert(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], "No highlighting: " .. ft)
end

assert(#errors == 0, table.concat(errors, "\n"))
print("Neovim smoke: LSP capabilities, formatters, telescope and 7 parser/filetype mappings passed")
vim.cmd("qa!")
