-- :checkhealth config — external binaries this config shells out to.
-- These install via `brew bundle` from ~/.config/homebrew/Brewfile.dev.
local M = {}

local deps = {
  { bin = "rg", why = "project text search (Space /)" },
  { bin = "fd", why = "explorer typed filter and file pickers" },
  { bin = "lazygit", why = "git UI (Space g g)" },
  { bin = "tree-sitter", why = "building syntax-highlighting parsers" },
  -- cc is OS-provided (Bluefin base image), not a Brewfile entry
  { bin = "cc", why = "compiling tree-sitter parsers" },
}

-- Names of deps that aren't on PATH.
function M.missing()
  return vim.tbl_map(
    function(dep) return dep.bin end,
    vim.tbl_filter(function(dep) return vim.fn.executable(dep.bin) ~= 1 end, deps)
  )
end

-- One-time startup warning; full detail lives in :checkhealth config.
function M.notify_missing()
  local missing = M.missing()
  if #missing > 0 then
    vim.notify(
      ("Missing external deps: %s\nFix: brew bundle --file ~/.config/homebrew/Brewfile.dev\nDetails: :checkhealth config"):format(table.concat(missing, ", ")),
      vim.log.levels.WARN,
      { title = "config.health" }
    )
  end
end

function M.check()
  vim.health.start("External dependencies (Brewfile.dev)")
  for _, dep in ipairs(deps) do
    if vim.fn.executable(dep.bin) == 1 then
      vim.health.ok(("%s — %s"):format(dep.bin, dep.why))
    else
      vim.health.error(
        ("%s missing — needed for %s"):format(dep.bin, dep.why),
        "Install: brew bundle --file ~/.config/homebrew/Brewfile.dev"
      )
    end
  end
end

return M
