-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- VSCode comfort layer -------------------------------------------------------
-- Ctrl+S (save) is already a LazyVim default, no mapping needed here.
local map = vim.keymap.set

-- Ctrl+P: fuzzy file picker (VSCode "Quick Open")
map({ "n", "i", "v" }, "<C-p>", function()
  Snacks.picker.files()
end, { desc = "Find Files (VSCode Ctrl+P)" })

-- Ctrl+Shift+P: command palette (needs a terminal with the kitty keyboard
-- protocol, e.g. Ghostty, to distinguish it from plain Ctrl+P)
map({ "n", "i", "v" }, "<C-S-p>", function()
  Snacks.picker.commands()
end, { desc = "Command Palette (VSCode Ctrl+Shift+P)" })

-- Ctrl+/: toggle comment. LazyVim binds this to a terminal by default; we
-- move the terminal to Ctrl+` (below) and make Ctrl+/ comment like VSCode.
-- <C-_> is what older terminal encodings send for Ctrl+/, map both.
for _, key in ipairs({ "<C-/>", "<C-_>" }) do
  map("n", key, "gcc", { remap = true, desc = "Toggle Comment (VSCode Ctrl+/)" })
  map("i", key, "<Esc>gcca", { remap = true, desc = "Toggle Comment (VSCode Ctrl+/)" })
  map("v", key, "gc", { remap = true, desc = "Toggle Comment (VSCode Ctrl+/)" })
end

-- Ctrl+`: toggle terminal, same key as VSCode
map({ "n", "i", "v" }, "<C-`>", function()
  Snacks.terminal()
end, { desc = "Toggle Terminal (VSCode Ctrl+`)" })
map("t", "<C-`>", "<cmd>close<cr>", { desc = "Hide Terminal (VSCode Ctrl+`)" })

-- Alt+B: toggle the file explorer sidebar. VSCode uses Ctrl+B, but herdr's
-- prefix key swallows that before nvim sees it, so Alt it is.
map("n", "<M-b>", function()
  Snacks.explorer()
end, { desc = "Toggle Explorer (VSCode Ctrl+B, remapped for herdr)" })
