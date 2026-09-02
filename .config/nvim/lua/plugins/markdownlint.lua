-- Lint Markdown with rumdl instead of LazyVim's default markdownlint-cli2, so
-- the editor and the guards plugin's lint-markdown hook report identical
-- findings from one config: ~/.config/rumdl/rumdl.toml, which rumdl discovers
-- on its own (XDG) when a project has no .rumdl.toml / .markdownlint.* of its
-- own. nvim-lint's built-in rumdl linter passes --stdin-filename, so discovery
-- is anchored to the buffer's file, not nvim's cwd. rumdl comes from Homebrew
-- (Brewfile.dev), not mason.
--
-- stream override: nvim-lint's rumdl definition (2025-11) reads stderr, but
-- rumdl 0.2.x writes `--output json` to stdout, so without this no diagnostics
-- ever appear (verified headless 2026-09-02).
return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        rumdl = { stream = "stdout" },
      },
      linters_by_ft = {
        markdown = { "rumdl" },
        ["markdown.mdx"] = { "rumdl" },
      },
    },
  },
}
