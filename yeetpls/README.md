# yeetpls #
A fairly simple script that leverages more complex parsers to delete entries from playlist files after they have finished playing.
The main script only determines the type of playlist given and tries to call `<filetype>-parser.lua` to handle the parsing code.
If it can't find an applicable parser, it will try to parse any playlist type **the way mpv processes plaintext playlists**. Notably: every line should be just an entry you can play by itself when using `mpv <entry>`.
If this doesn't work, it notifies the user with an `error` message and exits.

This script does not care about where it's being run from. So long as mpv can resolve the file names from the playlist, it's assumed this script can as well with no extra info

## Parsers ##
A new parser for a type of playlist files should provide at least one function:
- `format_pls`:
	- Arguments given to a parser are always the same, in the given order:
		- The playlist as read from the file, as a string.
			- This is the _original file_ and entries have **not yet been removed**.
		- The `playlist` object as returned by mpv's `mp.get_property_native("playlist")`.
			- In Lua, this becomes an indexed table of tables:
			- Top level: `ipair`s of a number and a table to determine the order;
			- Inner table: `pair`s of Stream Type (string) and the actual URL.
	- The value returned should be a string that can be written to a playlist file, according to the playlist spec.
	- **Make sure to add it to the module's exported function list**. The parser will be `require`d dynamically so if you don't expose `parser.format_pls`, it can't be used.

Whatever else these parsers do internally is irrelevant, make them perform black magic for all I care.
So long as it translates between mpv's internal playlist objects and the type of playlist it processes, this code is gonna be happy with it.

## Notes ##
This script assumes that **there is no shuffle applied**. It was made with the intention of automating the entire process from acquiring anime down to watching the show without doing anything
other than pointing mpv to a playlist. I personally set up a simple script to run on download completion that automatically generates a file `playlist.txt` which is just a list of file names
in the directory that don't match certain patterns.

If you apply shuffle, make sure that the playlist format you use gets processed by a parser that actually filters the entries by comparison. The `txt` parser is guaranteed to provide
this functionality, because the file format is extremely easy to use and the largest workload is extracting all remaining file names.

~~the `txt` parser is also the only one guaranteed to actually exist. I'm lazy and if it works for _me_, I'm usually happy~~
