-- local mp already exists. Preloaded by mpv itself
local opts = require("mp.options")
local utils = require("mp.utils")
local msg = require("mp.msg")
local parser = nil
local options = {
	-- The OS type, or an approximation anyway. auto makes the script check it
	system = "auto",
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
	playlist = "None" -- ("None" | "[/path/to/]<playlist_file.ext>")
}
opts.read_options(options, "yeetpls")

function base_init()
	--check OS type, borrowed from https://github.com/jonniek/mpv-playlistmanager/blob/8f01f38d71bdf02a3b61988a940a5fc0db3b573c/playlistmanager.lua#L171
	if options.system=="auto" then
	  local o = {}
	  if mp.get_property_native('options/vo-mmcss-profile', o) ~= o then
	    options.system = "windows"
	  else
	    options.system = "linux"
	  end
	end
	if options.playlist_type == "auto" then
		local filetype = options.playlist:reverse():match('.*%p'):reverse():sub(2)
		print("Reading playlist of type "..filetype)
		parser = require(filetype.."-parser")
	end
end

if not options.playlist == "None" then
	print("No playlist given in the form of --script-opts=yeetpls-playlist=playlist.ext\n\tExiting extension...")
	return
else
	base_init()
end
