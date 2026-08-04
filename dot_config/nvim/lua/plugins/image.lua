-- Inline image rendering, used for mermaid diagrams in markdown fences and in
-- standalone .mmd/.mermaid files.
--
-- .chezmoiignore does not gate .config/nvim, so this same file runs on Arch,
-- macOS and WSL — but the dependencies don't exist everywhere. Guard at runtime
-- so WSL degrades to plain (treesitter-highlighted) source instead of erroring.
local has_magick = vim.fn.executable("magick") == 1
local has_mmdc = vim.fn.executable("mmdc") == 1

return {
  {
    "3rd/image.nvim",
    enabled = has_magick,
    -- Stops lazy.nvim trying to build the (unneeded) magick luarock.
    build = false,
    event = "VeryLazy",
    opts = {
      -- No terminal detection: the backend is whatever we set, regardless of
      -- $TERM. Ghostty reports xterm-256color, which probe-based plugins miss.
      backend = "kitty",
      -- Default; shells out to the ImageMagick CLI, so no luarock needed.
      processor = "magick_cli",
      tmux_show_only_in_active_window = true,
    },
  },
  {
    "3rd/diagram.nvim",
    enabled = has_magick and has_mmdc,
    ft = { "markdown", "mermaid" },
    dependencies = { "3rd/image.nvim" },
    -- Function form: the integration module isn't on the rtp until load time.
    opts = function()
      -- diagram.nvim ships integrations for markdown and neorg only. A standalone
      -- .mmd/.mermaid file (filetype mapped in config/prose.lua) has no fenced
      -- block to query, so supply an integration where the whole buffer is the
      -- diagram. Shape matches what diagram.nvim expects of an integration:
      -- { id, filetypes, renderers, query_buffer_diagrams(bufnr) -> Diagram[] }.
      local mermaid_file = {
        id = "mermaid-file",
        filetypes = { "mermaid" },
        renderers = { require("diagram.renderers").mermaid },
        query_buffer_diagrams = function(bufnr)
          bufnr = bufnr or vim.api.nvim_get_current_buf()
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
          -- mmdc errors on empty input; render nothing until there's a diagram.
          if table.concat(lines, ""):match("^%s*$") then return {} end
          return {
            {
              bufnr = bufnr,
              renderer_id = "mermaid",
              source = table.concat(lines, "\n"),
              range = { start_row = 0, start_col = 0, end_row = #lines - 1, end_col = 0 },
            },
          }
        end,
      }

      return {
        integrations = {
          require("diagram.integrations.markdown"),
          mermaid_file,
        },
        renderer_options = {
          mermaid = {
            background = "transparent",
            theme = "dark", -- matches Glassmorphic Dark
          },
        },
      }
    end,
  },
}
