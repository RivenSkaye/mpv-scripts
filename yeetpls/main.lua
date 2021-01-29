-- local mp already exists. Preloaded by mpv itself
local opts = require("mp.options")
local utils = require("mp.utils")
local msg = require("mp.msg")
local filetype = nil -- used internally in places for the error state
local parser = nil -- The parser used internally, set during init.
local parser_name = nil -- This value is only used when stuff errors
local pls_old = nil -- The old playlist file's content
local mpv_pls = nil -- populated internally with mpv's playlist
local script_dir = nil
local options = {
	make_config = true,
	-- whether or not to auto-delete playlist entries after playing them
	auto_delete_entries = true, -- (*true | false)
	-- Whether to delete the playlist file if the last file is played
	auto_delete_file = true, -- (*true | false)
	-- The type of playlist, used for processing defaults internally. Default is "auto" and makes the script check it
	-- This list of filetypes is arbitrary and "auto" will allow for parsing anything that has a parser script available
	playlist_type = "auto", -- ("txt" | *"auto" | the name of any of the existing parsers)
	-- The playlist file. Due to limitations in the Lua env, this needs to be passed as a script-opt.
	-- This playlist is parsed internally and only parses playlist types for which a parser is available.
	playlist = "None", -- ("None" | "[/path/to/]<playlist_file.ext>")
	-- Whether to create the playlist file if it doesn't exist yet
	create_file = false, -- (true | *false)
	-- Emergency exit option. The only use-case is when people set up a config file for this script
	-- that sets a default playlist file to load and either
	-- create_file=true or has mpv running with --idle=[once | yes]
	-- or if the playlist file already exists and is set in the config
	exit = false
}
opts.read_options(options, "yeetpls")

-- Basic initialization. Wrapped in a function so we can properly exit the script if anything fails
function base_init()
	if options.playlist_type == "auto" then -- Determine the type of playlist, this is based on the extension
		filetype = options.playlist:reverse():match('.*%p'):reverse():sub(2)
		msg.info("Reading playlist of type "..filetype)
		options.playlist_type = filetype
		-- More than willing to accept PRs that add tables to map extensions to playlist types,
		-- in order to allow one parser to be used with any legal file type extension
	else
		filetype = options.playlist_type -- It's expected that users know what they're doing when setting this opt
		-- If you named your file "some.esoteric.format.kekw", but it's just plaintext, don't touch this.
		-- If it's anything that just lists a file per line like it's `ls`, leave this option alone.
		-- By default, it tries to parse unknown filetypes as `txt`
		-- This is mostly a development option for testing new parsers and speeding things up.
		-- Use this if you know exactly what parser you need to skip all checks on it.
	end
	-- Not sure what happens if I define a new variable and use an existing one,
	-- better make sure both exist.
	local hasparser = false
	-- Test if we have a parser for this
	hasparser,parser = pcall(require, filetype.."-parser")
	if not hasparser then
		-- default to the txt-parser
		msg.warn("No "..filetype.."-parser.lua found, trying to parse as text file")
		parser = require("txt-parser")
		parser_name = "txt-parser"
		-- Perform a special check in txt-parser.lua to see if this is a plaintext playlist.
		-- This is _only_ done for the txt-parser as it's the base to build on and the only feasible check.
		if not parser.check_txt(options.playlist) then
			msg.error("txt-parser was unable to process this file. Exiting...")
			return false
		end
	else
		-- We have a parser, save the name in case of errors
		parser_name = filetype.."-parser"
	end
	-- Open the file for appending and reading, this tests for both read and write permissions.
	local pls_file,err,errcode = nil,nil,nil
	if not options.create_file then
		pls_file,err,errcode = io.open(options.playlist, "r")
		if err then
			msg.error("File '"..options.playlist.."' does not exist and create_file script-opt was not set to true. Exiting...")
			return false
		end
		pls_file:close()
	end
	pls_file,err,errcode = io.open(options.playlist, "a+")
	if err then -- We don't have write access, error and exit
		msg.error("Recieved error code "..errcode..": "..err..".\nCannot process playlist, exiting...")
		return false
	else
		pls_old = pls_file:read("*all") -- Save the old playlist, should be fairly small
		pls_file:close() -- Close the file properly
		mpv_pls = mp.get_property_native("playlist") -- Array of objects => indexed table of tables. [{"filename", <file path>}...]
	end
	-- Everything was successful, time to actually do stuff here!
	return true
end

if options.playlist == "None" or options.exit then -- silently exit
	return
else
	if not base_init() then -- something caused a failure, exit.
		msg.error(parser_name.." was unable to parse this playlist type ("..filetype.."). Exiting...")
		return
	elseif #mpv_pls == 0 then
		mp.commandv('loadlist', options.playlist, 'append')
	end
end
-- If and only if we're successful, create the config file if it doesn't exist yet
-- If the script is global and the user wants their own custom config, they can do it themselves
if options.make_config then
	-- create the config file and alert the user
	local config_file = mp.get_script_directory():gsub("scripts[/|\\].*", "script-ops/yeetpls.conf")
	if mp.get_property_native('options/vo-mmcss-profile', o) ~= o then
		config_file = config_file:gsub("/", "\\")
	end
	local file,err,errcode = io.open(config_file, "w+")
	if not err then
		msg.error("Couldn't create config file, recieved error "..errcode..": "..err)
		msg.info("To prevent getting this message again, make sure the script can write to '"..config_file.."' or create a default config file for yeetpls that sets make_config=false")
	else
		msg.info("Setting all defaults for the script settings. Using current settings from --script-ops except for make_config, playlist_type and playlist")
		file:write("# Config file for the yeetpls Lua script. All options are followed by a comment listing all legal values, the default for the script is indicated with *\n\n")
		file:write("# Whether or not to (re)create the default config file\nmake_config=false # [true | *false]\n\n")
		file:write("# Whether or not to delete entries in the playlist file, makes VERY little sense to turn off\nauto_delete_entries="..options.auto_delete_entries.." # [*true | false]\n\n")
		file:write("# Whether or not to delete the playlist file after finishing the last file\nauto_delete_file="..options.auto_delete_files.." # [*true | false]")
		file:write("# The type of playlist, and by extension what parser, to use. The script can figure this out during runtime.\nplaylist_type=auto # [*auto | txt | ...] make sure this matches one of the *-parser.lua files exactly!")
		file:write("# Playlist file to load. Setting this here can cause some issues, so be careful!\nplaylist=None # [None | any file path or name you want]")
		file:write("# Whether or not to create the playlist file if it doesn't already exist. Some edge cases can cause issues.\ncreate_file=false\n\n")
		file:write("# Emergency option to exit the script without doing anything. THIS SHOULD ONLY BE SET TO TRUE THROUGH --SCRIPT-OPS. Disables the script entirely!\nexit=false\n")
		-- Files should end with a blank line, this is common sense.
	end
end

local pls_deleted = false -- prevents shutdown from eof before writing to file
function pls_remove(event)
	-- If a user quits midway through, don't delete the entry.
	-- Skipping to next should have another reason according to docs
	-- Error is an external issue, better not remove the entry so the user can debug
	if event.reason == "quit" or event.reason == "error" or not options.auto_delete_entries then
		return
	end
	-- Any other reason is a go-ahead to remove
	local plsID = event.playlist_entry_id
	-- remove it from the comparison table
	mpv_pls:remove(plsID)
	-- If the last file finishes playing, reason is still eof
	-- So check if this was the last entry and if so, delete the playlist file.
	if #mpv_pls == 0 then
		os.remove(options.playlist)
		pls_deleted = true
	end
end
mp.register_event("end-file", pls_remove)

function finalize(event)
	if pls_deleted then
		-- this is only true if the last file in the playlist was played and
		-- was skipped or reached eof.
		-- And skipping to next is impossible on the last file.
		return
	end
	if #mpv_pls > 0 then
		local pls_file,err,errcode = io.open(options.playlist, "w+")
		if err then
			msg.error("Ran into an unexpected problem opening '"..options.playlist.."', can't write playlist! Exiting...")
			return
		end
		local write_data = parser.format_pls(pls_old, mpv_pls)
		pls_file:write(write_data) -- It doesn't matter to mpv if there's a newline at the end
	end
end
mp.register_event("shutdown", finalize)
