if vim.g.loaded_vimaro then
	return
end
vim.g.loaded_vimaro = true

local function vimaro()
	return require("vimaro")
end

vim.api.nvim_create_user_command("FigFix", function(opts)
	vimaro().fix(opts)
end, { range = true, desc = "figaro: propose a fix as a diff, apply on y" })

vim.api.nvim_create_user_command("FigAt", function(opts)
	vimaro().attend(vim.trim(opts.args))
end, {
	nargs = "?",
	desc = "figaro: attend an aria (no argument opens a picker)",
	complete = function(lead)
		local ids = {}
		for _, a in ipairs(require("vimaro.aria").list()) do
			for _, name in ipairs({ a.handle, a.id }) do
				if name and vim.startswith(name, lead) then
					table.insert(ids, name)
				end
			end
		end
		return ids
	end,
})

vim.api.nvim_create_user_command("FigQ", function(opts)
	if opts.args ~= "" then
		vimaro().send(opts.args)
	elseif opts.range > 0 then
		vimaro().send(table.concat(vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false), "\n"))
	else
		vimaro().compose()
	end
end, { nargs = "?", range = true, desc = "figaro: send a prompt (argument, range, or compose buffer)" })

vim.api.nvim_create_user_command("FigDetach", function()
	vimaro().detach()
end, { desc = "figaro: drop the attended aria" })

vim.api.nvim_create_user_command("FigListen", function()
	vimaro().listen()
end, { desc = "figaro: open the attended aria in a terminal" })

vim.api.nvim_create_user_command("FigStatus", function()
	vimaro().status()
end, { desc = "figaro: status of the attended aria" })

vim.keymap.set({ "n", "x" }, "<Plug>(vimaro-fix)", function()
	vimaro().fix()
end, { desc = "figaro: fix" })
