# yeetpls #
A fairly simple script that leverages more complex parsers to delete entries from playlist files after they have finished playing.
The main script only determines the type of playlist given and tries to call `<filetype>-parser.lua` to handle the parsing code.
If it can't find an applicable parser, it will try to parse any playlist type **the way mpv processes plaintext playlists**. Notably: every line should be just an entry you can play by itself when using `mpv <entry>`.
If this doesn't work, it notifies the user with an `error` message and exits.

This script does not care about where it's being run from. So long as mpv can resolve the file names from the playlist, it's assumed this script can as well with no extra info

## Usage Notes ##
Due to a [limitation in mpv](#Known-Issues), you must pass the playlist file to `--script-ops=yeetpls-playlist=<file>`. Thanks to the `loadlist` internal input command, this script can **replace**
the need for an input file or the use of the `--playlist` option.
Optionally also pass the script-opt `create_file=true` if it doesn't exist and you want it to be made. _If it doesn't exist and you don't pass this option, it **will** error and exit._
Current behavior is to bypass read check on the file and immediately open it in `a+` for reading, appending and creating.

This script assumes that **there is no shuffle applied**. It was made with the intention of automating the entire process from acquiring anime down to watching the show without doing anything
other than pointing mpv to a playlist. I personally set up a simple script to run on download completion that automatically generates a file `playlist.txt` which is just a list of file names
in the directory that don't match certain patterns. If you apply shuffle, make sure that the playlist format you use gets processed by a parser that actually filters the entries by comparison.
The `txt` parser is guaranteed to provide this functionality, because the file format is extremely easy to use and the largest workload is extracting all remaining file names.
Creating a playlist for it is as easy as redirecting the output of `ls` (or `dir` with the correct flags under Windows) to a text file,
or just aggregating all full paths for the media you want in it in a single file. One playlist entry per line, as per mpv's plaintext playlist handler.

~~the `txt` parser is also the only one guaranteed to actually exist. I'm lazy and if it works for _me_, I'm usually happy~~

## Known issues ##
### Specifying the playlist twice ###
Currently, due to a limitation of mpv, the script is unable to fetch the playlist file provided with the `--playlist` command line option. Because it's not good practice to gamble on how
a playlist file gets provided, the script currently requires a user to set a script-opt instead. The script-opt to be set is `yeetpls-playlist`, as per the standard outlined on mpv.io to
automatically look for any script-opt named {script_name}-{opt_name}.

Yes, this means specifying the file twice, or setting `--idle=[once | yes]`. Don't complain to me about this, I'm just the messenger. I already sent in a [feature request](https://github.com/mpv-player/mpv/issues/8508)
to fix this, including all information I could get my hands on in regards to getting the playlist files. Someone suggested a possible fix on init time, but it doesn't work with the `--playlist` option.
Feel free to suggest other ways of attempting to get the file though!
_Behavior for this problem might change to instead attempt to load the playlist from just the script-opt and having the user add the flag to not close on idling. This remains to be seen as it changes
the requirements to parsers as well, to read playlists on start and parse them to a table instead of just the other way around. Imagine the extra effort this would take_

## Adding New Parsers ##
A new parser for a type of playlist files should provide at least two functions:
- `format_pls`:
	- Arguments given to a parser are always the same, in the given order:
		- The playlist as read from the file, as a string.
			- This is the _original file_ and entries have **not yet been removed**.
		- The `playlist` object as returned by mpv's `mp.get_property_native("playlist")`.
			- In Lua, this becomes an indexed table of tables:
			- Top level: `ipair`s of a number and a table to determine the order;
			- Inner table: `pair`s of Stream Type (string) and the actual URL.
	- The value returned should be a string that can be written to a playlist file, according to the playlist spec.
- `test_format`:
	- Argument given for this function is always just the content of the file.
	- The value returned should be a boolean.
	- If multiple format specs allow for the same parser to be used (m3u/m3u8 for example), an extra step is required:
		- Mention this in any PR to add functionality
		- Provide a list of all formats that match
		- Explain _why_ this shouldn't be a separate parser. Following m3u8 example: does mpv handle the charset internally?
		- This will probably end up with a translation table of `format, parser` where there will be duplicate entries in the parser field
			- Feel free to suggest a better fix :^)
	- Provide an internal way of matching the spec
	- Try to also match the current file content
		- Examples include not adding optional fields that the file currently doesn't use
		- Not dropping fields that could fairly easily be implemented
		- If a file takes note of URL/local file/webstream, please try to match this in the output
	- Do not throw errors if a file is a mismatch to the spec
		- Either use `print` or `mp.msg.warn` to notify the user of this.
		- Optionally print a single line message on the OSD
		- `return false` makes main.lua attempt to use a fallback, if that fails it provides a clean exit.

**Make sure to add these to the module's exported function list**. The parser will be `require`d dynamically so if you don't expose `parser.format_pls`, it can't be used.

Whatever else these parsers do internally is irrelevant, make them perform black magic for all I care.
So long as it translates between mpv's internal playlist objects and the type of playlist it processes, [this code](./main.lua) is gonna be happy with it.
