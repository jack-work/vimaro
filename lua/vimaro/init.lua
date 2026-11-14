local config = require("vimaro.config")

local M = {}

function M.setup(opts)
	config.set(opts)
	return M
end

function M.fix(opts)
	require("vimaro.fix").fix(opts)
end

function M.attend(id, then_do)
	require("vimaro.aria").attend(id, then_do)
end

function M.detach()
	require("vimaro.aria").detach()
end

function M.send(text)
	require("vimaro.aria").send(text)
end

function M.prompt(visual)
	require("vimaro.aria").prompt(visual)
end

function M.compose(seed)
	require("vimaro.aria").compose(seed)
end

function M.listen()
	require("vimaro.aria").listen()
end

function M.status()
	require("vimaro.aria").status()
end

function M.statusline()
	return require("vimaro.aria").statusline()
end

return M
