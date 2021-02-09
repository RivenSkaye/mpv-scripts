-- Parser for playlists in the simple and extended m3u formats.
-- Works for both normal m3u and m3u8 since mpv handles the character sets.
-- This thing checks if the format is correct and if it's simple format,
-- it returns the txt-parser since they're equal.
-- The extended format gets all file info parsed out, which is then sent to
-- the txt-parser for further processing and checking.

-- let mpv handle broken entries, this is fine if people use sane entries.
-- If it breaks, shame on them. Fix your files please.
txt_base = require("txt-parser")
parser = {}

function check_for_ext(pls_in)
	local firstline = pls_in:match(".-[^\r\n]")
	local header = "#EXTM3U" -- this MUST be full uppercase.
	return firstline == header
end

function split_entries(pls_in)
	local entrypattern = "%#EXTINF%:%d+,.-[\r\n]+.-[\r\n]+" -- Grab anything and everything that isn't the next header
	local entries = {}
	local pls = pls_in:gsub("#EXTM3U[\r\n]+", "") -- we'll yeet the header for comparisons, since we know it's there already
	for match in pls:gmatch(entrypattern) do
		-- Split off the filename, check it with txt_parser and if it matches, add the entry
	end
end
