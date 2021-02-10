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

function in_mpv(mpv_tbl, search)
	for i,e in ipairs(mpv_tbl) do -- for index, entry in mpv's playlist
		for k,v in pairs(e) do -- for key, value in index
			if k:lower() ~= "playing" and k:lower() ~= "current" then
				if search == v then
					return true
				end
			end
		end
	end
	return false
end

function check_for_ext(pls_in)
	local firstline = pls_in:match(".-[\r\n]+") -- fetch the header with newlines
	local header = "#EXTM3U" -- this MUST be full uppercase.
	-- strip off newlines for the comparison, return value with newlines to check
	-- if we can reconstruct the file
	return firstline:gsub("[\r\n]+", "") == header, firstline
end

function split_entries(pls_in)
	local entrypattern = "%#EXTINF%:%-?%d+,.-[\r\n]+.-[\r\n]+" -- Grab anything and everything that isn't the next header
	local entries = {}
	local pls = pls_in:gsub("#EXTM3U[\r\n]+", "") -- we'll yeet the header for comparisons, since we know it's there already
	for match in pls:gmatch(entrypattern) do
		filepath = match:gsub("%#EXTINF%:%-?%d+,.-[\r\n]+", ""):gsub("[\r\n]+", "") -- remove info header and trailing newlines
		if not txt_base.test_entry(filepath) then
			return false
		end
		table.insert(entries, match)
	end
	-- No need to keep a count of entries, m3u doesn't list that anyways
	return true, entries
end

function parser.test_format(pls)
	-- For creatign playlist files
	if pls == "" then return true end
	local header_pass, header = check_for_ext(pls)
	if not header_pass then
		-- This isn't an Extended m3u, thus it should be a list of files
		return txt_base.test_format(pls)
	end
	local content_pass, entries = split_entries(pls)
	if not content_pass then return false end
	local reconstruct = header..table.concat(entries, "")
	if reconstruct == pls then
		return true
	else
		return false
	end
end

function parser.format_pls(pls_in, mpv_pls)
	-- creating a file? Then we're letting the txt-parser handle it.
	-- This makes a valid simple m3u file. I didn't make the spec, I just laugh at it.
	if pls == "" then return txt_base.format_pls(pls_in, mpv_pls) end
	local header = "#EXTM3U\n"
	local _, pls_tbl = split_entries(pls_in)
	local pls_out = {}
	for i,v in ipairs(pls_tbl) do
		local search = v:gsub("%#EXTINF%:%-?%d+,.-[\r\n]+", ""):gsub("[\r\n]+", "")
		if in_mpv(mpv_pls, search) then
			table.insert(pls_out, v)
		end
	end
	return header..table.concat(pls_out, "")
end
