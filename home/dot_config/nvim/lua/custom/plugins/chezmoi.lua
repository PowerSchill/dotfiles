-- chezmoi
-- https://github.com/xvzc/chezmoi.nvim

return {
  'xvzc/chezmoi.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('chezmoi').setup {
      -- your configurations
    }
  end,
}
