if vim.g.loaded_nfig then
	return
end
vim.g.loaded_nfig = true

local function nfig()
	return require("nfig")
end

vim.api.nvim_create_user_command("FigFix", function(opts)
	nfig().fix(opts)
end, { range = true, desc = "figaro: propose a fix as a diff, apply on y" })

vim.api.nvim_create_user_command("FigAt", function(opts)
	nfig().attend(vim.trim(opts.args))
end, {
	nargs = "?",
	desc = "figaro: attend an aria (no argument opens a picker)",
	complete = function(lead)
		local ids = {}
		for _, a in ipairs(require("nfig.aria").list()) do
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
		nfig().send(opts.args)
	elseif opts.range > 0 then
		nfig().send(table.concat(vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false), "\n"))
	else
		nfig().compose()
	end
end, { nargs = "?", range = true, desc = "figaro: send a prompt (argument, range, or compose buffer)" })

vim.api.nvim_create_user_command("FigDetach", function()
	nfig().detach()
end, { desc = "figaro: drop the attended aria" })

vim.api.nvim_create_user_command("FigListen", function()
	nfig().listen()
end, { desc = "figaro: open the attended aria in a terminal" })

vim.api.nvim_create_user_command("FigStatus", function()
	nfig().status()
end, { desc = "figaro: status of the attended aria" })

vim.keymap.set({ "n", "x" }, "<Plug>(nfig-fix)", function()
	nfig().fix()
end, { desc = "figaro: fix" })
