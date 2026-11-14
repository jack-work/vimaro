# nfig

Neovim plugin for [figaro](https://github.com/jack-work/figaro).

## Install

lazy.nvim:

```lua
{
	"jack-work/nfig",
	cmd = { "FigAt", "FigQ", "FigListen", "FigStatus", "FigDetach" },
	opts = {},
	keys = {
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
})
```

| option | meaning |
|---|---|
| `cmd` | figaro executable |
| `forget` | send to an attended aria with `-f` and return at once |
| `notify` | report sends with `vim.notify`; errors always show |
| `compose_ft` | filetype of the compose buffer |

## License

MIT
