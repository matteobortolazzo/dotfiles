-- https://github.com/smolck/command-completion.nvim

return {
  'smolck/command-completion.nvim',
  config = function()
    require('command-completion').setup()
  end,
}
