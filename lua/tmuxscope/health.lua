--[[
--
-- Health check for tmuxscope.nvim
-- Checks that tmux, telescope, and plugin configuration are working correctly.
--
--]]

local function check_neovim_version()
	local verstr = string.format('%s.%s.%s', vim.version().major, vim.version().minor, vim.version().patch)
	
	if vim.version.cmp(vim.version(), { 0, 7, 0 }) >= 0 then
		vim.health.ok(string.format("Neovim version is: '%s'", verstr))
	else
		vim.health.error(string.format("Neovim out of date: '%s'. tmuxscope requires Neovim >= 0.7.0", verstr))
	end
end

local function check_external_dependencies()
	-- Check for tmux
	if vim.fn.executable('tmux') == 1 then
		local handle = io.popen('tmux -V 2>/dev/null')
		if handle then
			local version = handle:read('*a'):gsub('\n', '')
			handle:close()
			vim.health.ok(string.format("Found tmux: %s", version))
		else
			vim.health.ok("Found executable: 'tmux'")
		end
	else
		vim.health.error("Could not find executable: 'tmux' - this is required for tmuxscope to work")
		vim.health.info("Install tmux: https://github.com/tmux/tmux")
	end

	-- Check for other useful tools
	for _, exe in ipairs { 'find', 'mkdir' } do
		if vim.fn.executable(exe) == 1 then
			vim.health.ok(string.format("Found executable: '%s'", exe))
		else
			vim.health.warn(string.format("Could not find executable: '%s'", exe))
		end
	end
end

local function check_telescope()
	local telescope_ok, telescope = pcall(require, 'telescope')
	if telescope_ok then
		vim.health.ok("telescope.nvim is available")
		
		-- Check if tmuxscope extension is loaded
		if telescope.extensions and telescope.extensions.tmuxscope then
			vim.health.ok("tmuxscope extension is loaded")
		else
			vim.health.warn("tmuxscope extension is not loaded")
			vim.health.info("Load the extension with: require('telescope').load_extension('tmuxscope')")
		end
	else
		vim.health.error("telescope.nvim is not available")
		vim.health.info("Install telescope.nvim: https://github.com/nvim-telescope/telescope.nvim")
	end
end

local function check_tmux_environment()
	local tmux_env = os.getenv('TMUX')
	if tmux_env then
		vim.health.ok("Running inside tmux session")
		vim.health.info("Session switching will work directly")
	else
		vim.health.info("Not running inside tmux")
		vim.health.info("New sessions will be created detached, you'll need to attach manually")
	end
end

local function check_plugin_config()
	local tmuxscope_ok, tmuxscope = pcall(require, 'telescope._extensions.tmuxscope')
	if tmuxscope_ok and tmuxscope.config then
		vim.health.ok("tmuxscope configuration found")
		
		-- Check search paths
		if tmuxscope.config.search_paths and #tmuxscope.config.search_paths > 0 then
			local valid_paths = 0
			vim.health.info(string.format("Configured search paths (%d):", #tmuxscope.config.search_paths))
			
			for _, path in ipairs(tmuxscope.config.search_paths) do
				local expanded_path = vim.fn.expand(path)
				if vim.fn.isdirectory(expanded_path) == 1 then
					vim.health.info(string.format("  ✓ %s → %s", path, expanded_path))
					valid_paths = valid_paths + 1
				else
					vim.health.warn(string.format("  ✗ %s → %s (directory does not exist)", path, expanded_path))
				end
			end
			
			if valid_paths > 0 then
				vim.health.ok(string.format("%d/%d search paths are valid", valid_paths, #tmuxscope.config.search_paths))
			else
				vim.health.error("No valid search paths found")
			end
		else
			vim.health.warn("No search paths configured")
		end
		
		-- Check tmux command
		if tmuxscope.config.tmux_command then
			if vim.fn.executable(tmuxscope.config.tmux_command) == 1 then
				vim.health.ok(string.format("Configured tmux command '%s' is available", tmuxscope.config.tmux_command))
			else
				vim.health.error(string.format("Configured tmux command '%s' is not available", tmuxscope.config.tmux_command))
			end
		end
	else
		vim.health.warn("tmuxscope configuration not found, using defaults")
	end
end

local function check_tmux_functionality()
	if vim.fn.executable('tmux') == 1 then
		-- Test basic tmux functionality
		local handle = io.popen('tmux list-sessions 2>/dev/null')
		if handle then
			local result = handle:read('*a')
			handle:close()
			vim.health.ok("tmux list-sessions command works")
			
			if result and result ~= "" then
				local session_count = 0
				for line in result:gmatch("[^\r\n]+") do
					session_count = session_count + 1
				end
				vim.health.info(string.format("Found %d existing tmux session(s)", session_count))
			else
				vim.health.info("No existing tmux sessions found")
			end
		else
			vim.health.warn("tmux list-sessions command failed")
		end
	end
end

return {
	check = function()
		vim.health.start('tmuxscope.nvim')

		vim.health.info([[tmuxscope.nvim - A telescope extension for tmux session management

This health check verifies that tmux, telescope, and the plugin are configured correctly.]])

		local uv = vim.uv or vim.loop
		vim.health.info('System Information: ' .. vim.inspect(uv.os_uname()))

		check_neovim_version()
		check_external_dependencies()
		check_telescope()
		check_tmux_environment()
		check_plugin_config()
		check_tmux_functionality()

		vim.health.start('Summary')
		vim.health.info('Use :Telescope tmuxscope sessions to browse tmux sessions')
		vim.health.info('Use :Telescope tmuxscope new to create new sessions')
		vim.health.info('Report issues at: https://github.com/yourusername/tmuxscope.nvim/issues')
	end,
}
