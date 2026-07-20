-- Show all files in the explorer and pickers by default: both hidden
-- (dotfiles) and gitignored. `H` toggles hidden off, `I` toggles ignored
-- off if you ever want a cleaner view. Note: in $HOME the inverse-allowlist
-- gitignore means ignored=true surfaces every untracked file (Downloads,
-- caches, etc.), which is the intended "see everything" behavior here.
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
        },
      },
    },
  },
}
