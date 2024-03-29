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
local no_print = false
local options = {
	makeConfig = "yes",
	-- whether or not to auto-delete playlist entries after playing them
	autoDeleteEntries = "yes", -- (*yes | no)
	-- Whether to delete the playlist file if the last file is played
	autoDeleteFile = "yes", -- (*yes | no)
	-- The type of playlist, used for processing defaults internally. Default is "auto" and makes the script check it
	-- This list of filetypes is arbitrary and "auto" will allow for parsing anything that has a parser script available
	playlistType = "auto", -- ("txt" | *"auto" | the name of any of the existing parsers)
	-- The playlist file. Due to limitations in the Lua env, this needs to be passed as a script-opt.
	-- This playlist is parsed internally and only parses playlist types for which a parser is available.
	playlist = "None", -- ("None" | "[/path/to/]<playlist_file.ext>")
	-- Whether to create the playlist file if it doesn't exist yet
	createFile = "no", -- (yes | *no)
	-- Emergency exit option. The only use-case is when people set up a config file for this script
	-- that sets a default playlist file to load and either
	-- createFile=true or has mpv running with --idle=[once | yes]
	-- or if the playlist file already exists and is set in the config
	exit = "no" -- (yes | *no)
}
opts.read_options(options, "yeetpls")

-- Basic initialization. Wrapped in a function so we can properly exit the script if anything fails
function base_init()
	local typetranslation = {
		m3u8 = "m3u" -- No need to add m3u, since it translates to that ...
	}
	if options.playlistType == "auto" then -- Determine the type of playlist, this is based on the extension
		-- More than willing to accept PRs that add tables to map extensions to playlist types,
		-- in order to allow one parser to be used with any legal file type extension
		filetype = options.playlist:reverse():match(".*%p"):reverse():sub(2):lower()
		if typetranslation[filetype] ~= nil then -- ... So the key m3u would evaluate to nil ...
			filetype = typetranslation[filetype]
		end
		msg.info("Reading playlist of type " .. filetype)
		options.playlistType = filetype -- .. And this would still be m3u
	else
		-- If you named your file "some.esoteric.format.kekw", but it's just plaintext, don't touch this.
		-- If it's anything that just lists a file per line like it's `ls`, leave this option alone.
		-- By default, it tries to parse unknown filetypes as `txt`
		-- This is mostly a development option for testing new parsers and speeding things up.
		-- Use this if you know exactly what parser you need to skip all checks on it.
		filetype = options.playlistType -- It's expected that users know what they're doing when setting this opt
	end
	-- Not sure what happens if I define a new variable and use an existing one,
	-- better make sure both exist.
	local hasparser = false
	-- Test if we have a parser for this
	hasparser, parser = pcall(require, filetype .. "-parser")
	if not hasparser then
		-- default to the txt-parser
		msg.warn("No " .. filetype .. "-parser.lua found, trying to parse as text file")
		parser = require("txt-parser")
		parser_name = "txt-parser"
	else
		-- We have a parser, save the name in case of errors
		parser_name = filetype .. "-parser"
	end
	-- Open the file for appending and reading, this tests for both read and write permissions.
	local pls_file, err, errcode = nil, nil, nil
	if options.createFile ~= "yes" then
		pls_file, err, errcode = io.open(options.playlist, "r")
		if err then
			msg.error(
				"File '" .. options.playlist .. "' does not exist and createFile script-opt was not set to 'yes'. Exiting..."
			)
			no_print = true
			pls_file:close()
			return false
		end
		pls_file:close()
	end
	pls_file, err, errcode = io.open(options.playlist, "a+")
	if err then -- We don't have write access, error and exit
		msg.error("Recieved error code " .. errcode .. ": " .. err .. ".\nCannot process playlist, exiting...")
		pls_file:close()
		return false
	else
		pls_old = pls_file:read("*all") -- Save the old playlist, should be fairly small
		pls_file:close() -- Close the file properly
		mpv_pls = mp.get_property_native("playlist") -- Array of objects => indexed table of tables. [{"filename", <file path>}...]
	end
	if not parser.test_format(pls_old) then
		return false
	end
	-- Everything was successful, time to actually do stuff here!
	return true
end

if options.playlist == "None" or options.exit == "yes" then -- exit since we're useless here
	msg.info("No playlist being played. Exiting...")
	return
else
	if not base_init() then -- something caused a failure, exit.
		if not no_print then -- quick hack to see if it was a nu_file issue
			msg.error(parser_name .. " was unable to parse this playlist type (" .. filetype .. "). Exiting...")
		end
		return
	elseif #mpv_pls == 0 then -- a playlist file wasn't loaded, so it's empty and idle
		mp.commandv("loadlist", options.playlist, "append")
		-- make seure we get a correct count now
		mpv_pls = mp.get_property_native("playlist") -- Array of objects => indexed table of tables. [{"filename", <file path>}...]
	else
		msg.warn(
			"There are already files being played by mpv, this means playlist integrity cannot be guaranteed. Exiting..."
		)
		return
	end
end
-- If and only if we're successful, create the config file if it doesn't exist yet
-- If the script is global and the user wants their own custom config, they can do it themselves
if options.makeConfig == "yes" then
	-- create the config file and alert the user
	local config_file = mp.get_script_directory():gsub("scripts[/|\\].*", "script-opts/yeetpls.conf")
	local o = {}
	if mp.get_property_native("options/vo-mmcss-profile", o) ~= o then
		config_file = config_file:gsub("/", "\\")
	end
	local file, err, errcode = io.open(config_file, "w+")
	if err then
		msg.error("Couldn't create config file, recieved error " .. tostring(errcode) .. ": " .. tostring(err))
		msg.info(
			"To prevent getting this message again, make sure the script can write to '" ..
				config_file .. "' or create a default config file for yeetpls that sets makeConfig=no"
		)
	else
		-- Files should end with a newline, this is common sense.
		msg.info(
			"Setting all defaults for the script settings. Using current settings from --script-opts except for makeConfig, playlistType and playlist"
		)
		file:write(
			"# Config file for the yeetpls Lua script. All options are followed by a comment listing all legal values, the default for the script is indicated with *\n"
		)
		file:write("# Whether or not to (re)create the default config file\nmakeConfig=no\n# [yes | *no]\n\n")
		file:write(
			"# Whether or not to delete entries in the playlist file, makes VERY little sense to turn off since it's what the script was made for\nautoDeleteEntries=" ..
				tostring(options.autoDeleteEntries) .. "\n# [*yes | no]\n\n"
		)
		file:write(
			"# Whether or not to delete the playlist file after finishing the last entry\nautoDeleteFile=" ..
				tostring(options.autoDeleteFile) .. "\n# [*yes | no]\n\n"
		)
		file:write(
			"# The type of playlist, and by extension what parser, to use. The script can figure this out during runtime.\nplaylistType=auto\n# [*auto | txt | ...] make sure this matches one of the *-parser.lua files exactly!\n\n"
		)
		file:write(
			"# Playlist file to load. Setting this here can cause some issues, so be careful!\nplaylist=None\n# [*None | any file path or name you want]\n\n"
		)
		file:write(
			"# Whether or not to create the playlist file if it doesn't already exist. Some edge cases can cause issues.\ncreateFile=no\n# [yes | *no]\n\n"
		)
		file:write(
			"# Emergency option to exit the script without doing anything. THIS SHOULD ONLY BE SET TO TRUE THROUGH --SCRIPT-OPTS. Disables the script entirely!\nexit=no\n# [*no | *no | *no | yes]\n"
		)
		file:close()
	end
end

local cur_index = 0
function get_pls_id(event)
	cur_index = mp.get_property_native("playlist-pos")
end
mp.register_event("start-file", get_pls_id)
local cidle, cerr = mp.get_property_bool("core-idle")
local pause, perr = mp.get_property_bool("pause")
if cidle == true or (pause == true and cerr) then
	mp.commandv("playlist-play-index", "0")
elseif cerr or perr then
	msg.warn("Something went wrong trying to play the first file, you'll have to do it manually!")
end

local pls_deleted = false -- prevents shutdown from eof before writing to file
function pls_remove(event)
	-- If a user quits midway through, don't delete the entry.
	-- Skipping to next should have another reason according to docs
	-- Error is an external issue, better not remove the entry so the user can debug
	if event.reason == "quit" or event.reason == "error" or options.autoDeleteEntries ~= "yes" then
		return
	end
	mp.commandv("playlist-remove", tostring(cur_index))
	mpv_pls = mp.get_property_native("playlist")
	-- If the last file finishes playing, reason is still eof
	-- So check if this was the last entry and if so, delete the playlist file.
	if #mpv_pls == 0 and options.autoDeleteFile == "yes" then
		os.remove(options.playlist)
		pls_deleted = true
	end
end
mp.register_event("end-file", pls_remove)

function finalize(event)
	if pls_deleted then
		msg.info("Finished playback, deleted '" .. options.playlist .. "'.")
		-- this is only true if the last file in the playlist was played and removed
		return
	end
	if #mpv_pls > 0 then
		local pls_file, err, errcode = io.open(options.playlist, "w+")
		if err then
			msg.error("Ran into an unexpected problem opening '" .. options.playlist .. "', can't write playlist! Exiting...")
			pls_file:close()
			return
		end
		local write_data = parser.format_pls(pls_old, mpv_pls)
		local o = {}
		if mp.get_property_native("options/vo-mmcss-profile", o) ~= o then
			-- Make sure all newlines are okay on Windows
			-- Input might have \r\n, or it may have \n. So we take two steps:
			-- Replace every \n with \r\n, this causes any \r\n to become \r\r\n
			-- Then we replace every \r\r with \r so it's \r\n again
			write_data = write_data:gsub("\n", "\r\n"):gsub("\r\r", "\r")
		else
			write_data = write_data:gsub("\r", "") -- And we might as well shave off \r otherwise
		end
		pls_file:write(write_data) -- It doesn't matter to mpv if there's a newline at the end
		msg.info(
			"Wrote the remaining " .. tostring(#mpv_pls) .. " files to '" .. options.playlist .. "' for your convenience."
		)
		pls_file:close()
	end
	mp.unregister_event(pls_remove)
	mp.unregister_event(get_pls_id)
	mp.unregister_event(finalize)
end
mp.register_event("shutdown", finalize)
