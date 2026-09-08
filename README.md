# bs.nvim

One-letter marks ("harpoon-style") for whole files: `<A-m>{char}` names the current file, `<leader>'` opens a transient deck to flick between them.

Heavily inspired by [harpoon](https://github.com/ThePrimeagen/harpoon)\; the bundled `<C-s>` terminal toggle comes from [Justin M. Keyes' config](https://github.com/justinmk/config/blob/master/.config/nvim/lua/my/ctrl_s_shell.lua).

## Keys

| Keys                     | Action                                             |
| ------------------------ | -------------------------------------------------- |
| `<A-m>{char}`            | mark current file as `{char}` (one-shot)           |
| `<A-,>{char}`            | unmark `{char}` (one-shot)                         |
| `<leader>'`              | open/close marks deck                              |
| in deck: `{char}`        | jump to `{char}` and close                         |
| in deck: `<CR>`          | jump the highlighted mark, close                   |
| in deck: `'`             | toggle sticky (deck stays open while flicking)     |
| in deck: `<C-s>`         | open highlighted mark in a horizontal split        |
| in deck: `<C-v>`         | open highlighted mark in a vertical split          |
| in deck: `<C-t>`         | open highlighted mark in a new tabpage             |
| in deck: `<C-p>`/`<C-n>` | move the highlight up/down                         |
| in deck: `<Esc>`         | close deck                                         |
| `<C-s>`                  | toggle terminal (own tab first, foreground after)  |
| `'<C-s>`                 | show terminal in the current window (no split/tab) |
| `[count]<C-s>`           | open terminal as a split `count` lines tall        |

In sticky mode the deck stays open and the highlight follows the current file. Marks are session-only: file marks survive a wiped buffer (reopened from the absolute path); live marks (terminals/REPLs) must stay alive. Each mark keeps its cursor position. In the deck, `<C-s>` is the deck's split; outside it, the terminal's toggle.

## Default configuration

```lua
require("bs").setup({
  prefix           = "<leader>'", -- open/close the marks deck
  mark_prefix      = "<A-m>",     -- mark the current file
  unmark_prefix    = "<A-,>",     -- unmark
  confirm_reassign = true,        -- confirm before overwriting a used mark key
  mark_keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",

  deck = {
    select = "<CR>",  -- jump highlighted (current window)
    sticky = "'",     -- toggle sticky mode
    hsplit = "<C-s>", -- open highlighted in hsplit
    vsplit = "<C-v>", -- open highlighted in vsplit
    tab    = "<C-t>", -- open highlighted in new tab
    up     = "<C-p>", -- move highlight up
    down   = "<C-n>", -- move highlight down
    close  = "<Esc>", -- close deck
  },

  notify = true,

  terminal = {
    toggle = "<C-s>", -- toggle key ("" to disable)
    here    = false,  -- false: own tabpage; true: splits below
    scrollback = -1,  -- -1 = unlimited
  },
})
```

## Installation

Native packages (`vim.pack.add`, Neovim 0.11+):

```lua
vim.pack.add({ 'urtzienriquez/bs.nvim' })
```

Or any package manager, then:

```lua
require("bs").setup({})
```

## API

```lua
local bs = require("bs")

bs.setup(opts)   -- configure + bind keys
bs.deck()        -- open the deck (same as <leader>')
bs.mark(char)    -- mark the current file as char
bs.jump(char)    -- jump to the file marked char
bs.unmark(char)  -- remove the mark char
bs.terminal()    -- toggle the terminal (optional args: count, here)
```

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
