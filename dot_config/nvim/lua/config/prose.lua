-- Prose editing: soft wrap, spell checking, and the <leader>m markdown group.

-- Standalone diagram files get the mermaid parser installed by plugins/treesitter.lua.
vim.filetype.add({
  extension = {
    mmd = "mermaid",
    mermaid = "mermaid",
  },
})

-- Added words live in the dotfiles rather than only in ~/.local/state.
vim.opt.spellfile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add"

local prose_filetypes = { markdown = true, text = true, gitcommit = true }

--- Populate the location list with the current buffer's markdown headings.
local function markdown_outline()
  local buf = vim.api.nvim_get_current_buf()
  local items = {}
  local in_fence = false

  for lnum, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:match("^%s*```") then
      in_fence = not in_fence
    elseif not in_fence and line:match("^#+%s") then
      items[#items + 1] = { bufnr = buf, lnum = lnum, col = 1, text = line }
    end
  end

  if #items == 0 then
    vim.notify("No markdown headings found", vim.log.levels.INFO)
    return
  end

  vim.fn.setloclist(0, items, " ")
  vim.fn.setloclist(0, {}, "a", { title = "Markdown outline" })
  vim.cmd.lopen()
end

local function apply_prose_settings(buf)
  -- Soft wrap: break at word boundaries, never mid-word, and keep list items
  -- and blockquotes visually indented when they wrap.
  vim.opt_local.wrap = true
  vim.opt_local.linebreak = true
  vim.opt_local.breakindent = true
  vim.opt_local.showbreak = "↳ "

  vim.opt_local.spell = true
  vim.opt_local.spelllang = "en"

  -- Soft wrap for display, hard wrap only on demand: `t` is removed so typing
  -- never auto-breaks, but Q (mapped to gq) reflows a paragraph to 80.
  -- `n` keeps numbered lists intact when it does.
  vim.opt_local.textwidth = 80
  vim.opt_local.formatoptions = "jqln"

  -- Move by visual line, but keep counts working on logical lines (5j = 5 real lines).
  local opts = { buffer = buf, expr = true, silent = true }
  vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", vim.tbl_extend("force", opts, { desc = "Down (visual line)" }))
  vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", vim.tbl_extend("force", opts, { desc = "Up (visual line)" }))
end

local group = vim.api.nvim_create_augroup("Prose", { clear = true })

-- FileType alone sets window-local options on whichever window happened to
-- trigger it; BufWinEnter covers the same buffer opened in a second split.
vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group = group,
  callback = function(event)
    if prose_filetypes[vim.bo[event.buf].filetype] then
      apply_prose_settings(event.buf)
    end
  end,
})

-- Markdown-only <leader>m group (registered with which-key in plugins/which-key.lua).
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "markdown",
  callback = function(event)
    local opts = { buffer = event.buf, silent = true }

    vim.keymap.set("n", "<leader>md", function()
      local ok, diagram = pcall(require, "diagram")
      if not ok then
        vim.notify("diagram.nvim is not available (needs magick + mmdc)", vim.log.levels.WARN)
        return
      end
      diagram.show_diagram_hover()
    end, vim.tbl_extend("force", opts, { desc = "Diagram under cursor" }))

    vim.keymap.set("n", "<leader>mt", "<cmd>TableModeToggle<CR>", vim.tbl_extend("force", opts, { desc = "Toggle table mode" }))
    vim.keymap.set("n", "<leader>mz", "<cmd>ZenMode<CR>", vim.tbl_extend("force", opts, { desc = "Zen mode" }))
    vim.keymap.set("n", "<leader>mo", markdown_outline, vim.tbl_extend("force", opts, { desc = "Outline (headings)" }))
  end,
})
