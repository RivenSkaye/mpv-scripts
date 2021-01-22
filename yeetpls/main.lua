-- local mp already exists. Preloaded by mpv itself
local opts = require("mp.options")
local utils = require("mp.utils")
local msg = require("mp.msg")
local filetype = nil -- used internally in places for the error state
local mpv_pls = nil -- populated internally with mpv's playlist, so a list of
local parser = nil
local parser_name = nil -- This value is only used when stuff errors
local pls_old = nil
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
		print("Reading playlist of type "..filetype)
		-- More than willing to accept PRs that add tables to map extensions to playlist types,
		-- in order to allow one parser to be used with any legal file type extension
	else
		filetype = options.playlist_type -- It's expected that users know what they're doing when setting this opt
		-- If you named your file "some.esoteric.format.kekw", but it's just plaintext, you'll wanna set this.
		-- If it's anything that just lists a file per line like it's `ls`, leave this option alone.
		-- By default, it tries to parse unknown filetypes as `txt`
	end
	-- Not sure what happens if I define a new variable and use an existing one,
	-- better make sure both exist.
	local hasparser = nil
	-- Test if we have a parser for this
	hasparser,parser = pcall(require, filetype.."-parser")
	if not hasparser then
		-- default to the txt-parser
		parser = require("txt-parser")
		parser_name = "txt-parser"
	else
		-- We have a parser, save the name in case of errors
		parser_name = filetype.."-parser"
	end
	-- Open the file for appending and reading, this tests for both read and write permissions.
	local pls_file,err,errcode = io.open(options.playlist, "a+")
	if err then -- We don't have read and/or write, error and exit
		print("Recieved error code "..errcode..": "..err..".\nCannot process playlist, exiting...")
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
	print("No playlist given to the --script-opts=yeetpls=<playlist file> switch. Exiting extension...")
	return
else
	if not base_init() then -- something caused a failure, exit.
		print(parser_name.." was unable to parse this playlist type ("..filetype.."). Exiting...")
		return
	else
		-- TESTING INFO, success!
		print("loading "..parser_name.." was successful!")
	end
end
