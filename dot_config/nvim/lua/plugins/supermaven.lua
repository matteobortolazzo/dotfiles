-- Inline AI completion only — ghost text in insert mode, no chat window.
-- Claude Code runs in a tmux pane; nvim needs no chat integration.
return {
  "supermaven-inc/supermaven-nvim",
  event = "InsertEnter",
  opts = {
    -- Upstream defaults (<Tab>/<C-]>/<C-j>) all collide here: <Tab> is blink.cmp
    -- snippet_forward, <C-j> is window-down, <C-]> is built-in tag-jump.
    -- These match what copilot.lua used, so muscle memory carries over.
    keymaps = {
      accept_suggestion = "<M-l>",
      accept_word = "<M-k>",
      clear_suggestion = "<M-]>",
    },
    ignore_filetypes = { markdown = true, gitcommit = true },
    color = {
      suggestion_color = "#5a5752", -- Glassmorphic Dark `text-disabled`
      cterm = 244,
    },
    log_level = "warn",
  },
}
