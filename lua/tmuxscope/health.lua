local M = {}

local health = require("vim.health")

-- Helper function to check if a command exists
local function command_exists(cmd)
	local handle = io.popen("command -v " .. cmd .. " 2>/dev/null")
	if not handle then
		return false
	end
	local result = handle:read("*a")
	handle:close()
	return result and result ~= ""
end

-- Helper function to get command version
local function get_command_version(cmd, version_flag)
	version_flag = version_flag or "--version"
	local handle = io.popen(cmd .. " " .. version_flag .. " 2>/dev/null")
	if not handle then
		return nil
	end
	local result = handle:read("*a")
	handle:close()
	return result and result:match("[^\r\n]+") or nil
end

-- Check Neovim version
local function check_neovim()
	local required_version = { 0, 7, 0 }
	local current_version = vim.version()

	if vim.version.cmp(current_version, required_version) >= 0 then
		health.info(string.format("Neovim version: %s", vim.version.tostring(current_version)))
		health.ok("Neovim version is compatible")
	else
		health.error(
			string.format(
				"Neovim version %s is too old. Required: >= %s",
				vim.version.tostring(current_version),
				vim.version.tostring(required_version)
			)
		)
	end
end

-- Check telescope availability
local function check_telescope()
	local telescope_ok, telescope = pcall(require, "telescope")
	if telescope_ok then
		health.ok("telescope.nvim is available")

		-- Check if tmuxscope extension is loaded
		local extensions = telescope.extensions or {}
		if extensions.tmuxscope then
			health.ok("tmuxscope extension is loaded")
		else
			health.warn("tmuxscope extension is not loaded. Run :Telescope load_extension tmuxscope")
		end
	else
		health.error("telescope.nvim is not installed or not available")
		health.info("Install telescope.nvim: https://github.com/nvim-telescope/telescope.nvim")
	end
end

-- Check tmux availability
local function check_tmux()
	if command_exists("tmux") then
		local version = get_command_version("tmux", "-V")
		if version then
			health.info("tmux version: " .. version)
			health.ok("tmux is available")

			-- Test tmux functionality
			local handle = io.popen("tmux list-sessions 2>/dev/null")
			if handle then
				handle:close()
				health.ok("tmux list-sessions command works")
			else
				health.warn("tmux list-sessions command failed")
			end
		else
			health.warn("tmux is available but version could not be determined")
		end
	else
		health.error("tmux is not installed or not in PATH")
		health.info("Install tmux: https://github.com/tmux/tmux")
	end
end

-- Check tmuxscope configuration
local function check_configuration()
	local tmuxscope_ok, tmuxscope = pcall(require, "telescope._extensions.tmuxscope")
	if not tmuxscope_ok then
		health.error("tmuxscope extension module could not be loaded")
		return
	end

	-- Check if config exists and has valid search paths
	if tmuxscope.config then
		health.ok("tmuxscope configuration found")

		if tmuxscope.config.search_paths and #tmuxscope.config.search_paths > 0 then
			health.info(string.format("Configured search paths (%d):", #tmuxscope.config.search_paths))

			local valid_paths = 0
			for _, path in ipairs(tmuxscope.config.search_paths) do
				local expanded_path = vim.fn.expand(path)
				if vim.fn.isdirectory(expanded_path) == 1 then
					health.info(string.format("  ✓ %s → %s", path, expanded_path))
					valid_paths = valid_paths + 1
				else
					health.warn(string.format("  ✗ %s → %s (directory does not exist)", path, expanded_path))
				end
			end

			if valid_paths > 0 then
				health.ok(string.format("%d/%d search paths are valid", valid_paths, #tmuxscope.config.search_paths))
			else
				health.error("No valid search paths found")
			end
		else
			health.warn("No search paths configured")
		end

		-- Check tmux command
		if tmuxscope.config.tmux_command then
			local cmd = tmuxscope.config.tmux_command
			if command_exists(cmd) then
				health.ok(string.format('Configured tmux command "%s" is available', cmd))
			else
				health.error(string.format('Configured tmux command "%s" is not available', cmd))
			end
		else
			health.warn("No tmux command configured")
		end
	else
		health.warn("tmuxscope configuration not found, using defaults")
	end
end

-- Check if we're in tmux environment
local function check_tmux_environment()
	local tmux_env = os.getenv("TMUX")
	if tmux_env then
		health.info("Running inside tmux session")
		health.ok("Session switching will work directly")
	else
		health.info("Not running inside tmux")
		health.info("New sessions will be created detached, you'll need to attach manually")
	end
end

-- Check common dependencies
local function check_dependencies()
	-- Check for common utilities used by the extension
	local utilities = {
		{ cmd = "find", desc = "Required for directory scanning" },
		{ cmd = "mkdir", desc = "Required for directory creation" },
	}

	for _, util in ipairs(utilities) do
		if command_exists(util.cmd) then
			health.ok(string.format("%s is available", util.cmd))
		else
			health.error(string.format("%s is not available - %s", util.cmd, util.desc))
		end
	end
end

-- Main health check function
function M.check()
	health.start("tmuxscope.nvim health check")

	check_neovim()
	check_telescope()
	check_tmux()
	check_configuration()
	check_tmux_environment()
	check_dependencies()

	health.start("Summary")
	health.info("Run :help tmuxscope for documentation")
	health.info("Report issues at: https://github.com/yourusername/tmuxscope.nvim/issues")
end

return M
