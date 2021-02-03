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

-- Split all entries in the playlist file.
-- Even though it's just newlines for this, it makes for a nice skeleton for other parsers.
function split_entries(pls)
	local ret = {}
	for str in pls:gmatch("[^\r\n|^\r|^\n]+") do
		table.insert(ret, str)
	end
	return ret
end

-- Create the required functions within parser
function parser.format_pls(pls_in, mpv_pls)
	-- Split the entries by newlines, these can be '\r', '\n' or '\r\n'
	local pls_tbl = {}
	for str in pls_in:gmatch("[^\r\n|^\r|^\n]+") do
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

-- Test if the input format matches the expected input and return a Boolean.
-- Do this however seems most fit for the parser you wrote.
-- In practice, the only cgar that is truly illegal to add to a URI is NULL.
-- The pain of patterns drove me to this point of "fuck it". Let mpv error if a name is borked instead.
function parser.test_format(pls)
	-- Checks all valid chars in file paths. Allows for periods in paths,
	-- allows for files without extension.
	local pass = true
	local entries = split_entries(pls)
	local t = {}
	local fwp = "^%a:[\\/][.-\\/]*.+%.%w+" -- Full Windows path
	local fnp = "/[.-/]*.+%.%w+" -- full *NIX path
	local rfp = "[%.+\\/]?[.-\\/]*.+%.%w+" -- relative file path
	local jaf = ".+%.%w+" -- Just a file
	local upe = "%a+://[.+%.]?%w+%.%w+[/.]*" -- URL playlist entry
	for index,entry in ipairs(entries) do
		if not entry:find("[^%z<>:%|%?%*\"]") then -- This path contains disallowed chars. Win == NIX here, due to effort and media should work everywhere.
			pass=false
		elseif not entry:find(fwp) or not entry:find(fnp) or not entry:find(rfp) or not entry:find(jaf) then -- check for paths here. If we don't find them...
			if not entry:find(upe) then -- check for URLs. If none:
				pass=false -- it matches no known inputs
			end
		end
	end
	return pass -- All entries passed the test, playlist is correct if this is true.
end

-- Return the module for use in main.lua
return parser
