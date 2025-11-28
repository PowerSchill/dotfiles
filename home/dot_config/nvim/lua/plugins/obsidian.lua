return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  ft = "markdown",
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  -- event = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
  --   -- refer to `:h file-pattern` for more examples
  --   "BufReadPre path/to/my-vault/*.md",
  --   "BufNewFile path/to/my-vault/*.md",
  -- },
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false, -- this will be removed in the next major release
    ---------------------------------------------------------------------------
    -- Daily Notes
    ---------------------------------------------------------------------------
    daily_notes = {
      -- This is the *base folder* for daily notes.
      -- Your prefix goes here:
      folder = "00-09 System/02 Journal/02.01 Daily",
      date_format = "%Y-%m-%d",
    },
    ---------------------------------------------------------------------------
    -- Custom path logic for daily notes
    ---------------------------------------------------------------------------
    ---@param spec { id: string, dir: obsidian.Path, title: string|? }
    note_path_func = function(spec)
      local id = tostring(spec.id)

      -- Detect daily-note IDs (YYYY-MM-DD)
      local y, m, d = id:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
      if y and m and d then
        --
        -- Daily note → <daily_notes.folder>/YYYY/MM/YYYY-MM-DD.md
        --
        local path = spec.dir / y / m / id
        return path:with_suffix(".md")
      end

      -- Default for non-daily notes:
      return (spec.dir / id):with_suffix(".md")
    end,
    workspaces = {
      {
        name = "Personal",
        path = "~/Obsidian/Personal System",
      },
    },

    -- see below for full list of options 👇
  },
}
