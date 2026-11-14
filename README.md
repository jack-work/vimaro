# nfig

Neovim plugin for [figaro](https://github.com/jack-work/figaro).

`grf` asks a cheap figaro to fix the code under the cursor. The answer
comes back as a unified diff, shown in a float; `y` applies it, `n`
throws it away.

## Install

lazy.nvim:

```lua
{
	"jack-work/nfig",
	cmd = { "FigFix", "FigAt", "FigQ", "FigListen", "FigStatus", "FigDetach" },
	opts = {},
	keys = {
		{ "grf", "<Plug>(nfig-fix)", mode = { "n", "x" }, desc = "Fix with figaro" },
		{ "<leader>Fa", function() require("nfig").attend() end, desc = "Attend aria" },
		{ "<leader>Fq", function() require("nfig").prompt(false) end, desc = "Prompt figaro" },
		{ "<leader>Fq", function() require("nfig").prompt(true) end, mode = "x", desc = "Send selection" },
		{ "<leader>Fl", function() require("nfig").listen() end, desc = "Listen to aria" },
		{ "<leader>Fs", "<cmd>FigStatus<cr>", desc = "Aria status" },
		{ "<leader>Fd", "<cmd>FigDetach<cr>", desc = "Detach aria" },
	},
}
```

Needs Neovim 0.10 or later and `figaro` on `PATH`.

## grf

In normal mode `grf` sends the cursor line with five lines either side.
In visual mode it sends the selection. Either way figaro also gets the
file path, the filetype and the diagnostics on the cursor line (or in the
selection).

Each fix runs in a fresh figaro dressed in the `cheap` outfit, which is
killed as soon as the answer arrives. The diff is applied to the buffer,
not the file on disk, and in one undo step. Hunk line numbers from the
model are only a hint: hunks are placed by matching their context and
removed lines, nearest the cursor first.

`:FigFix` does the same; `:'<,'>FigFix` takes a range.

### The cheap outfit

grf expects an outfit named `cheap` in `~/.config/figaro/outfits/`. Keep
it small, static and tool-free:

```toml
# ~/.config/figaro/outfits/cheap.toml
[system]
provider        = "copilot"
model           = "gpt-5.6-luna"
thinking_effort = "low"
tools           = []
credo           = "You fix code. Answer with exactly what the request asks for and nothing else."
ttl             = "2m"

[system.methods]
enabled = false
```

`system.methods.enabled = false` stops figaro predicting the reasoning
effort per message, so `low` holds. nfig also sets `system.ttl` on each
fixing figaro to `fix.timeout_ms` plus 30 seconds, so one orphaned by a crash or a failed kill is
gone within two minutes.

## Talking to arias

Figaro's `attend` binds a shell pid, which means nothing to Neovim jobs,
so nfig remembers the attended aria itself and passes `--id`.

| command | does |
|---|---|
| `:FigAt` | pick an aria to attend |
| `:FigAt <id>` | attend that aria (completes handles and ids) |
| `:FigQ` | open a compose buffer; `:w` sends it |
| `:'<,'>FigQ` | send the range |
| `:FigQ <text>` | send the text |
| `:FigListen` | `figaro listen` in a terminal split |
| `:FigStatus` | `figaro status` of the attended aria |
| `:FigDetach` | forget the attended aria |

With nothing attended, sending offers a picker with a "new aria" entry.
`require("nfig").statusline()` returns `figaro:<id>` for a statusline.

## Options

```lua
require("nfig").setup({
	cmd = "figaro",
	forget = true,
	notify = true,
	compose_ft = "markdown",
	fix = {
		outfit = "cheap",
		delete = { "skills" },
		context = 5,
		timeout_ms = 90000,
	},
})
```

| option | meaning |
|---|---|
| `cmd` | figaro executable |
| `forget` | send to an attended aria with `-f` and return at once |
| `notify` | report sends and fixes with `vim.notify`; errors always show |
| `compose_ft` | filetype of the compose buffer |
| `fix.outfit` | outfit the fixing figaro wears |
| `fix.delete` | form keys removed at birth; `skills` keeps the skill index out of a one-shot request |
| `fix.context` | lines either side of the cursor in normal mode |
| `fix.timeout_ms` | give up on the model after this long |

## Tests

```sh
nvim -l tests/run.lua
```

## License

MIT
