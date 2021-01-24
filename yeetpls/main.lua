-- local mp already exists. Preloaded by mpv itself
local opts = require("mp.options")
local utils = require("mp.utils")
local msg = require("mp.msg")
local filetype = nil -- used internally in places for the error state
local parser = nil -- The parser used internally, set during init.
local parser_name = nil -- This value is only used when stuff errors
local pls_old = nil -- The old playlist file's content
local mpv_pls = nil -- populated internally with mpv's playlist
local pls_deleted = false -- prevents shutdown from eof from writing a new playlist file
local options = {
	-- whether or not to auto-delete playlist entries after playing them
	auto_delete_entries = true, -- (*true | false)
	-- Whether to delete the playlist file if the last file is played
	auto_delete_file = true, -- (*true | false)
	-- Print info like playlist length and title when starting
	info_on_start = true, -- (*true | false)
	-- Print info like remaining titles and title on the next entry
	info_on_next = false, -- (true | *false)

	-- The type of playlist, used for processing defaults internally. Default is "auto" and makes the script check it
	-- This list of filetypes is arbitrary and "auto" will allow for parsing anything that has a parser script available
	playlist_type = "auto", -- ("txt" | "m3u" | "m3u8" | "pls" | *"auto")
	-- The playlist file. Due to limitations in the Lua env, this needs to be passed as a script-opt.
	-- This playlist is parsed internally and only parses playlist types for which a parser is available.
	playlist = "None", -- ("None" | "[/path/to/]<playlist_file.ext>")
	-- Whether to create the playlist file if it doesn't exist yet
	create_file = false -- (true | *false)
}
opts.read_options(options, "yeetpls")

-- Basic initialization. Wrapped in a function so we can properly exit the script if anything fails
function base_init()
	if options.playlist_type == "auto" then -- Determine the type of playlist, this is based on the extension
		filetype = options.playlist:reverse():match('.*%p'):reverse():sub(2)
		msg.info("Reading playlist of type "..filetype)
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
	local hasparser = nil
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

if options.playlist == "None" then
	msg.error("No playlist given to the --script-opts=yeetpls-playlist=<playlist file> switch. Exiting extension...")
	return
else
	if not base_init() then -- something caused a failure, exit.
		msg.error(parser_name.." was unable to parse this playlist type ("..filetype.."). Exiting...")
		return
	else
		-- TESTING INFO, success!
		print("loading "..parser_name.." was successful!")
	end
end

function pls_remove(event)
	-- If a user quits midway through, don't delete the entry.
	-- Skipping to next should have another reason according to docs
	-- Error is an external issue, better not remove the entry so the user can debug
	if event.reason == "quit" or event.reason == "error" then
		return
	end
	-- Any other reason is a go-ahead to remove
	local plsID = event.playlist_entry_id
	-- If the last file finishes playing, reason is still eof
	-- So check if this was the last entry and if so, delete the playlist file.
	if #mpv_pls <= 1 then
		os.remove(options.playlist)
		pls_deleted = true
	end
	-- remove it from the comparison table
	mpv_pls:remove(plsID)
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
