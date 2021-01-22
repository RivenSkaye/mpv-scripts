# yeetpls #
A fairly simple script that leverages more complex parsers to delete entries from playlist files after they have finished playing.
The main script only determines the type of playlist given and tries to call `<filetype>-parser.lua` to handle the parsing code.
If it can't find an applicable parser, it will try to parse any playlist type **the way mpv processes plaintext playlists**. Notably: every line should be just an entry you can play by itself when using `mpv <entry>`.
If this doesn't work, it notifies the user with an `error` message and exits.

This script does not care about where it's being run from. So long as mpv can resolve the file names from the playlist, it's assumed this script can as well with no extra info

## Parsers ##
A new parser for a type of playlist files should provide a couple of functions with standardized names:
- `read_to_playlist`: Should take in a string (the full contents of the playlist file) and return a list of just the file entries. These should be kept as they are.
	- If supplied files are just filenames, return just filenames;
	- If supplied files are a full path, return full paths.
	- If supplied files are Windows paths, return Windows paths
	- And if they're relative, return them relative.
- `format_playlist`: Should take in a list of items and transform it to a playlist of the type it parses. It should return this as one long string
	- Stick to whatever the spec for the playlist type is
	- Ensure it's valid enough that it can be passed to mpv's `--playlist` switch and just play everything
Whatever else these parsers do internally is irrelevant. Make them perform black magic for all I care,
so long as it translates between mpv's internal playlist objects and the type of playlist it processes.
