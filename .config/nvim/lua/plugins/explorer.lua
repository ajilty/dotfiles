-- Show dotfiles (hidden files) in the explorer and pickers by default.
-- `H` still toggles them off; `I` toggles gitignored files (left off here
-- so $HOME's inverse-allowlist doesn't flood the tree with untracked files).
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = { hidden = true },
      },
    },
  },
}
