-- Simple parser for PLS files. Removes blank lines from the input.
-- This thing basically checks if the format is correct,
-- extracts all of the info and verifies file names and URLs by
-- shoving them into a list and having txt-parser deal with it.

-- Used for some lazy parsing, once again let mpv handle retarded entries, so
-- long as the format is valid
txt_base = require("txt-parser")
parser = {}

--- Split all entries in the playlist file
-- Takes into account the optional nature of
-- the Title and Length headers.
function split_entries(pls)
	-- retain newlines for verification at a later point in time
	local entryfile = "File%d=.-[\r\n]+"
	local entrytitle = "Title%d=.-[\r\n]+"
	local entrylength = "Length%d=%-?%d+[\r\n]+"

	-- Fetch a table of all lines in the file
	local entries = {}
	local total_entries = 0
	-- Remove the header and footer
	pls = pls:gsub("^%[playlist%][\r\n]-[^\r\n]"):gsub("[\r\n]+NumberOfEntries=%d+[\r\n]+Version=2[\r\n]*")
	-- Find a way to split on any combination of the above patterns
	-- gmatch every pattern, get the entry number and use that to get it in the table
	for match in pls:gmatch(entryfile) do
		local number = tonumber(pls:match("File%d+"):match("%d+"))
		entries[number] = match -- This is just the seed, hence why we can't concat it yet
		total_entries = total_entries + 1
	end
	for match in pls:gmatch(entrytitle) do
		local number = tonumber(pls:match("Title%d+"):match("%d+"))
		entries[number] = entries[number]..match -- This is just the seed, hence why we can't concat it yet
	end
	for match in pls:gmatch(entrylength) do
		local number = tonumber(pls:match("Length%d+"):match("%d+"))
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
		if pls:find(header) then
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
	local footer_pass, footer = verify_footer(pls, total)
	if footer_pass and header_pass then
		local reconstruct = header..table.concat(content, "")..footer
		if reconstruct == pls then -- Not stripping any newlines and other data should mean they're equal
			return true
		else
			return false
		end
	end
end
