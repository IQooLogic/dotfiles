return {
	{
		"scottmckendry/cyberdream.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("cyberdream").setup({
				-- Enable transparent background
				transparent = true,

				-- Enable italics comments
				italic_comments = false,

				-- Modern borderless telescope theme
				borderless_pickers = false,

				-- Set terminal colors used in `:terminal`
				terminal_colors = true,
			})
			vim.cmd("colorscheme cyberdream")
		end,
	},
}
