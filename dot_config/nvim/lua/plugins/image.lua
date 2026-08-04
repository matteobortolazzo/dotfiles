-- Inline image rendering, used for mermaid diagrams in markdown.
--
-- .chezmoiignore does not gate .config/nvim, so this same file runs on Arch,
-- macOS and WSL — but the dependencies don't exist everywhere. Guard at runtime
-- so WSL degrades to plain fenced code blocks instead of erroring.
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
    ft = { "markdown" },
    dependencies = { "3rd/image.nvim" },
    -- Function form: the integration module isn't on the rtp until load time.
    opts = function()
      return {
        integrations = {
          require("diagram.integrations.markdown"),
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
