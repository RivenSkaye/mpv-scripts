-- In order to test the input file for a variety of options, we'll need to also
-- take the OS-specific paths into account and the accepted ways of matching
-- files and paths. Which in Windows allows both forward and backward slashes
-- in most if not all cases.
-- Luckily new patterns have been set up that allow for both, interchangeably

local parser = {}
local mpv_tbl

-- Check if a value is a playlist entry. v[1] is "filename" or similar, v[2] is the entry
function in_mpv(val)
	for i,e in ipairs(mpv_tbl) do -- for index, entry in mpv's playlist
		for k,v in pairs(e) do -- for key, value in index
			if k:lower() ~= "playing" and k:lower() ~= "current" then
				if val == v then
					return true
				end
			end
		end
	end
	return false
end

--- Split all entries from the file content and return this as a table per line
-- Split all entries in the playlist file.
-- Even though it's just newlines for this, it makes for a nice skeleton for other parsers.
-- Exported for ease of use for other parsers as a split by line function
function parser.split_entries(pls)
	local ret = {}
	for str in pls:gmatch("[^\r\n]+") do
		table.insert(ret, str)
	end
	return ret
end

-- Create the required functions within parser
function parser.format_pls(pls_in, mpv_pls)
	-- Split the entries by newlines, these can be '\r', '\n' or '\r\n'
	local pls_tbl = {}
	for str in pls_in:gmatch("[^\r\n|^\r|^\n]+") do -- Not sure the pipes hold any special meaning, but it works on Windows at least
		table.insert(pls_tbl, str)
	end
	mpv_tbl = mpv_pls
	-- As strings are immutable, we'll leverage table.concat instead
	local pls_out = {}
	for i,v in ipairs(pls_tbl) do
		if in_mpv(v) then
			-- Yay, the value is still in the mpv playlist. Add it to the table
			table.insert(pls_out, v)
		end
	end
	-- Return the playlist as a concatenated string
	return table.concat(pls_out, "\n")
end

-- Used in both the parser.test_format and parser.testutil functions.
local illegal = "^%s?[^%z<>:%|%?%*\"]+[%s$]?[%.$]?" -- All chars illegal in Windows filenames. Also checks for the illegal start with whitespace and end with whitespace or periods
local fwp = "^%a:[\\/][.-\\/]*.+%.%w+" -- Full Windows path
local fnp = "/[.-/]*.+%.%w+" -- full *NIX path
local rfp = "[%.+\\/]?[.-\\/]*.+%.%w+" -- relative file path
local jaf = ".+%.%w+" -- Just a file
-- URIs have different legal and illegal characters. Anything not in the following list is never legal in a URI
local url_illegal = "[^%w%-%.%_%~%:%/%?%#%[%]%@%!%$%&%'%(%)%*%+%,%;%=%%]" -- the caret (^) denotes anything not in this list
local upe = "%a+://[.+%.]?%w+%.%w+[/.]*" -- URL playlist entry
-- Test if the input format matches the expected input and return a Boolean.
-- Do this however seems most fit for the parser you wrote.
-- In practice, the only cgar that is truly illegal to add to a URI is NULL.
-- The pain of patterns drove me to this point of "fuck it". Let mpv error if a name is borked instead.
function parser.test_format(pls)
	-- Checks all valid chars in file paths. Allows for periods in paths
	local pass = true
	local entries = split_entries(pls)
	for index,entry in ipairs(entries) do
		if parser.test_entry(entry) then pass = true end
	end
	return pass -- All entries passed the test, playlist is correct if this is true.
end

--- Special function exposed for other parsers that want to test a single
-- file name / path / URL rather than the entire playlist
-- I'm sure it's bugged as hell
-- @param entry The entry to test
-- @param[opt="all"] test Type of entry to check, use "all" for unknown.
-- Valid values are "all", "file", "path", "relative", "url"
-- @return Whether or not this matches any of the patterns requested.
function parser.test_entry(entry, test)
	local types = {
		file = {jaf},
		path = {fnp, fwp},
		relative = {rfp},
		all = {fwp, fnp, rfp, jaf}
	}
	local pass = true
	-- This contains illegal file names
	if not test == "url" and entry:find(illegal) then pass = false end
	if not test == "url" and pass then
		-- Check all of the requested patterns
		for i,v in ipairs(types[pls_type]) do
			-- If we find a match, return true
			if entry:find(v) then return true end
		end
		pass = false -- So far, no match. Prob illegal
	end
	if not entry:find(url_illegal) then
		if test == "all" or test == "url" then
			if entry:find(upe) then
				-- unless it's a valid URI
				pass = true
			end
		end
	end
	-- if all tests fail:
	return pass
end

-- Return the module for use in main.lua
return parser
