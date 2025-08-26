return {
  {
    "catppuccin/nvim",
    opts = function(_, opts)
      -- Required until https://github.com/LazyVim/LazyVim/pull/6354 is merged.
      local module = require("catppuccin.groups.integrations.bufferline")
      if module then
        module.get = module.get_theme
      end
      return opts
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha",
    },
  },
}
