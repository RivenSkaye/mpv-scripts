-- In order to test the input file for a variety of options, we'll need to also
-- take the OS-specific paths into account and the accepted ways of matching
-- files and paths. Which in Windows allows both forward and backward slashes
-- in most if not all cases.
-- Obviously this means making special cases for Windows. REEE
-- This also means that if you mix-and-match Windows paths and POSIX-compliant
-- paths, the parser will deem your playlist unparsable. Deal with it.

local parser = {}
local mpv_tbl

-- Check if a value is a playlist entry. v[1] is "filename" or similar, v[2] is the entry
function in_mpv(val)
	for i,v in ipairs(mpv_tbl) do
		if val == v[2] then
			return true
		end
	end
	return false
end

-- Split all entries in the playlist file.
-- Even though it's just newlines for this, it makes for a nice skeleton for other parsers.
function split_entries(pls)
	return pls:gmatch("[\r\n|\r|\n]")
end

-- Create the required functions within parser
function parser.format_pls(pls_in, mpv_pls)
	-- Split the entries by newlines, these can be '\r', '\n' or '\r\n'
	local pls_tbl = pls_in:gmatch("[\r\n|\r|\n]")
	mpv_tbl = mpv_pls
	-- As strings are immutable, we'll leverage table.concat instead
	local pls_out = {}
	for i,v in ipairs(pls_tbl) do
		if in_mpv(v) then
			-- Yay, the value is still in the mpv playlist. Add it to the table
			pls_out:insert(v)
		end
	end
	-- Return the playlist as a concatenated string
	return pls_out:concat("\n")
end

-- Test if the input format matches the expected input and return a Boolean.
-- Do this however seems most fit for the parser you wrote.
-- It is recommended to import this function into all other parsers to test
-- if the file paths are actually valid.
-- I'll deal with adding net streams later
function parser.test_format(pls)
	-- Checks all valid chars in file paths. Allows for periods in paths,
	-- allows for files without extension.
	local winpaths = "[%a:(/|\\)]?[[%w%s,;%.%-]+[/|\\]]?[%w%s,;%.%-]+[%.[%a+]]?$"
	local default_to_win = false
	-- Uses forward slashes instead of >Windows backslashes and mixed
	-- Allows (escaped) whitespace. Most often encountered on files made on a Windows
	-- 		machine, or mounted NTFS drives. Dual boot system pain
	-- 		Escaping whitespace might not be necessry for applications.
	local paths = "[/]?[[%w(\\?%s)%.%-]+/]*[%w(\\?%s)%.%-]+[%.[%a+]]?$"
	-- If we don't encounter anything weird, this stays true and we exit
	local pass = true
	local entries = split_entries(pls)
	local t = {}
	for index,entry in ipairs(entries) do
		if not default_to_win then
			if not entry:find(paths) then
				if not entry:find(winpaths) then
					pass = false
					break
				else
					default_to_win = true
				end
			end
		else
			if not entry:find(winpaths) then
				pass = false
				break
			end
		end
	end
	return pass -- All entries passed the test, playlist is correct.
end

-- Return the module for use in main.lua
return parser
