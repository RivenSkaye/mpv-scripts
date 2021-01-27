-- In order to test the input file for a variety of options, we'll need to also
-- take the OS-specific paths into account and the accepted ways of matching
-- files and paths. Which in Windows allows both forward and backward slashes
-- in most if not all cases.
-- Obviously this means making special cases for Windows. REEE

local parser = {}

-- Checks all valid chars in filepaths. Allows for periods in paths, allows no extension
-- (%a:\\)? = Drive letter, may occur once
-- (([\w,\s;-]+(%.+)?)+\\)* = Valid folder names, with periods. Add a backslash.
-- 		May occur an arbitrary number of times, file could be in the drive root
-- 		or it could be a relative path. Handles multiple periods in succession
-- 		so it allows relative paths like ..\ as well folder names with more than
-- 		one period in succession
-- ([\w,\s;-]+(\.(%a+))?$) = Match all valid filenames, optionally without extension
-- 		Filename with extension must be the end of it
local full_winpath = "(%a:\\)?(([\w,\s;-]+(%.+)?)+\\)*([\w,\s;\.-]+(\.(%a+))?$)"
-- Uses forward slashes instead of >Windows backslashes
-- Allows escaped whitespace. Most often encountered on files made on a Windows
-- 		machine, or mounted NTFS drives. Dual boot system pain
-- 		Escaping whitespace might not be necessry for applications.
local full_path = "/(([\w-]+((\\)?\s)*(%.+)?)+/)*([\w\.-]+((\\)?\s)*(\.(%a+))?$)"
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

-- Create the required functions within parser
function parser.format_pls(pls_in, mpv_pls)
	-- Split the entries by newlines, these can be '\r', '\n' or '\r\n'
	local pls_tbl = pls_in:gmatch("(\r\n)|(\r)|(\n)")
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

-- Return the module's functions for use in main.lua
return parser
