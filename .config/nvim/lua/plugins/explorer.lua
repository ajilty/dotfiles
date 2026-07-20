-- Show dotfiles (hidden files) in the explorer and pickers by default.
-- `H` still toggles them off; `I` toggles gitignored files (left off here
-- so $HOME's inverse-allowlist doesn't flood the tree with untracked files).
--
-- `include` globs force-show specific paths regardless of gitignore, so
-- dotfolders with no tracked contents (e.g. ~/.aws) still appear without
-- flipping `ignored` on globally. Add a folder by listing both its dir and
-- its contents: "**/.foo" and "**/.foo/**".
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          hidden = true,
          include = {
            "**/.aws",
            "**/.aws/**",
          },
        },
      },
    },
  },
}
