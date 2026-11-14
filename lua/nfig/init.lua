local config = require("nfig.config")

local M = {}

function M.setup(opts)
	config.set(opts)
	return M
end

function M.fix(opts)
	require("nfig.fix").fix(opts)
end

function M.attend(id, then_do)
	require("nfig.aria").attend(id, then_do)
end

function M.detach()
	require("nfig.aria").detach()
end

function M.send(text)
	require("nfig.aria").send(text)
end

function M.prompt(visual)
	require("nfig.aria").prompt(visual)
end

function M.compose(seed)
	require("nfig.aria").compose(seed)
end

function M.listen()
	require("nfig.aria").listen()
end

function M.status()
	require("nfig.aria").status()
end

function M.statusline()
	return require("nfig.aria").statusline()
end

return M
