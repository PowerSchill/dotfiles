-- catppucin
-- https://github.com/catppuccin/nvim

return {
  'catppuccin/nvim',
  name = 'catppuccin',
  priority = 1000,
  config = function()
    require('catppuccin').setup {
      integrations = {
        cmp = true,
        gitsigns = true,
        neotree = true,
        nvimtree = true,
        treesitter = true,
      },
    }
  end,
}
