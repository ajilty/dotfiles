-- Point markdownlint-cli2 at the global config (~/.markdownlint.yaml, which
-- disables MD013/line-length). Needed because markdownlint-cli2 only
-- auto-discovers config files from its cwd downward, so the $HOME-level file
-- is invisible when nvim's cwd is a project directory. --config sets the base
-- configuration; project-level .markdownlint.* files still override it.
return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          args = { "--config", vim.fn.expand("~/.markdownlint.yaml"), "-" },
        },
      },
    },
  },
}
