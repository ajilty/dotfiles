# Neovim cheatsheet (for the VSCode brain)

Open this anytime: `nvim ~/.config/nvim/CHEATSHEET.md`

## Survival basics

| Need | Do |
|---|---|
| I'm stuck / weird mode | Press `Esc` (maybe twice) |
| Type text | `i` (insert before cursor), `a` (after), then `Esc` when done |
| Save | `Ctrl+S` (yes, it works) |
| Quit | `Space q q`, or `:q` then Enter |
| Quit without saving | `:q!` then Enter |
| Undo / redo | `u` / `Ctrl+R` |
| Interactive tutorial | `:Tutor` (30 min, worth it) |

## Your VSCode shortcuts that work here

| VSCode | Here | Notes |
|---|---|---|
| `Ctrl+S` | same | Save file |
| `Ctrl+P` | same | Fuzzy file picker |
| `Ctrl+Shift+P` | same | Command palette |
| `Ctrl+/` | same | Toggle comment |
| ``Ctrl+` `` | same | Toggle terminal |
| `Ctrl+B` | same | Toggle file explorer sidebar |
| Mouse | same | Click, drag-select, scroll, resize splits, right-click menu |

## VSCode habit → the nvim way

| In VSCode you'd... | Here |
|---|---|
| `Ctrl+Shift+F` global search | `Space /` (search text in project) |
| `Ctrl+F` find in file | `/text` then Enter; `n` next, `N` previous |
| `F12` go to definition | `gd` |
| `Shift+F12` find references | `gr` |
| `F2` rename symbol | `Space c r` |
| `Ctrl+.` quick fix | `Space c a` (code action) |
| Hover for docs | `K` |
| `Ctrl+Tab` switch file | `Shift+H` / `Shift+L` cycle buffers, or `Space ,` buffer picker |
| `Ctrl+W` close file | `Space b d` (delete buffer) |
| Split editor | `Space w v` (vertical), `Space w s` (horizontal) |
| Git panel | `Space g g` (opens lazygit if installed) |
| Problems panel | `Space x x` |
| Settings | Edit `~/.config/nvim/lua/config/*.lua` |

## The one idea that makes vim click

Keys are a language: **verb + noun**. `d` = delete, `w` = word, so `dw` deletes a
word. `ci"` = change inside quotes. `y` = yank (copy), `p` = paste, `dd` = delete
line, `yy` = copy line. Learn a few nouns and every verb multiplies.

## Discovering everything else

- Press `Space` and **wait**: a menu pops up showing every command group.
- `Space s k` searches all keybindings by name.
- `:Lazy` manages plugins; `:Mason` manages language servers.
- Add language support: `:LazyExtras` (e.g. enable `lang.python`, `lang.go`).
