-- Simple parser for PLS files. Removes blank lines from the input.
-- This thing basically checks if the format is correct,
-- extracts all of the info and verifies file names and URLs by
-- shoving them into a list and having txt-parser deal with it.

-- Used for some lazy parsing, once again let mpv handle retarded entries, so
-- long as the format is valid
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

--- Split all entries in the playlist file
-- Takes into account the optional nature of
-- the Title and Length headers.
function split_entries(pls_in)
	-- retain newlines for verification at a later point in time
	local entryfile = "File%d=.-[\r\n]+"
	local entrytitle = "Title%d=.-[\r\n]+"
	local entrylength = "Length%d=%-?%d+[\r\n]*" -- Final newline gets stripped in the gsub

	-- Make a table for all entries in the file
	local entries = {}
	local total_entries = 0
	-- Remove the header and footer
	pls = pls_in:gsub("^%[playlist%][\r\n]+", ""):gsub("[\r\n]+NumberOfEntries=%d+[\r\n]+Version=2[\r\n]*", "")
	-- Find a way to split on any combination of the above patterns
	-- gmatch every pattern, get the entry number and use that to get it in the table
	for match in pls:gmatch(entryfile) do
		local number = tonumber(match:match("%d+"))
		entries[number] = match -- This is just the seed, hence why we can't concat it yet
		total_entries = total_entries + 1
		filename = match:gsub("File%d=", ""):gsub("[\r\n]+", "")
		if not txt_base.test_entry(filename) then
			return false
		end
	end
	for match in pls:gmatch(entrytitle) do
		local number = tonumber(match:match("%d+"))
		entries[number] = entries[number]..match -- This is just the seed, hence why we can't concat it yet
	end
	for match in pls:gmatch(entrylength) do
		local number = tonumber(match:match("%d+"))
		entries[number] = entries[number]..match -- This is just the seed, hence why we can't concat it yet
	end
	return entries, total_entries
end

--- Verifies a compliant PLS header and the fact that it occurs only once
-- throughout the entire playlist.
-- Allows [playlist] in a filename, as it checks for the entry to be the only
-- occurrence on the entire line
-- @param pls The contents of the entire playlist file in a string
function verify_header(pls)
	local header = "^%[playlist%]$"
	local count = 0
	local pls_lines = txt_base.split_entries(pls)
	for _,line in ipairs(pls_lines) do
		if line:find(header) then
			count = count + 1
		end
	end
	-- If there were more than 1 header, or no headers at all, this is invalid
	if count > 1 or count == 0 then
		return false
	end
	local fileheader = pls:match("^%[playlist%][\r\n]+")
	return true, fileheader
end

--- Verifies that the footer in the file is compliant to the spec, and
-- that it occurs only once. No need to check entries as the format for the
-- footer disables this option altogether.
-- Also verifies the NumberOfEntries property has a correct count
function verify_footer(pls, entries)
	local footer = "[\r\n]+NumberOfEntries=%d+[\r\n]+Version=2[\r\n]*"
	local count = select(2, pls:gsub(footer, ""))
	if count > 1 or count == 0 then
		return false
	end
	local number = tonumber(pls:match("NumberOfEntries=%d+"):match("%d+"))
	if not entries == number then
		return false
	end
	local filefooter = pls:match("[\r\n]+NumberOfEntries=%d+[\r\n]+Version=2[\r\n]*$")
	return true, filefooter
end

function parser.test_format(pls)
	local header_pass, header = verify_header(pls)
	local content, total = split_entries(pls)
	-- if split_entries finds illegal values, it returns false
	if not content then return false end
	local footer_pass, footer = verify_footer(pls, total)
	if footer_pass and header_pass then
		local reconstruct = header..table.concat(content, "")..footer
		if reconstruct == pls then -- Not stripping any legal data should mean they're equal
			return true
		else
			return false
		end
	end
	return false
end

function parser.format_pls(pls_in, mpv_pls)
	local header = "[playlist]\n"
	local footer = "\nNumberOfEntries=XXX\nVersion=2\n"
	local remaining = 0
	local pls_tbl, total_in = split_entries(pls_in)
	local pls_out = {}
	for i,v in ipairs(pls_tbl) do
		local search = v:gsub("File%d=", ""):gsub("[\r\n].*", "")
		if in_mpv(mpv_pls, search) then
			remaining = remaining + 1
			table.insert(pls_out, v)
		end
	end
	footer = footer:gsub("XXX", tostring(remaining))
	return header..table.concat(pls_out, "")..footer
end

return parser
