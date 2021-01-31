"""Installs the yeetpls mpv Lua script

Fetches the required files, outputs them to the correct directory and makes
sure that the OS can handle them. Makes some proper differentiations regarding
the OS, assuming it's run in the normal way. If anything seems off, cancel
this hunk-a-junk and just manually supply the directory you want the script in
using `python install.py -scripts "$HOME/.config/mpv/scripts/"`

I don't know and much less care to test what ~ does when used as input.
I prefer exact paths and have some notion of how variables can be resolved,
but by no means do I like doing what a decent user can tell their shell to do.

Author: RivenSkaye
"""
import urllib.request as req
import sys
import platform
from pathlib import Path
import os

# Lazy as hell, time to shorten this
argv = sys.argv
# Any of the help options found? Print help and exit, ignore the rest
helps = ['-h', '-help', '--h', '--help']
if any([h == a for h in helps for a in argv]) or len(argv) <= 1:
    print("Installs the yeetpls user script for mpv. Valid options are:")
    print("-default\t\tUses the default user-based scripts dir for this user. If this is supplied, specified folders get ignored.")
    print("-scripts <path/to/scripts/folder>\tSpecify a folder.")
    print("-h, -help, --h, --help\tSummons this message and exits. If this is present, all other options will be ignored.")
    print("Please do not input any environment variables other than '~' on Linux/Unix-like machines and '%APPDATA%' on Windows machines.")
    print("The script only handles these because they're listed in the default paths for mpv to store files, and are thus used internally.")
    print("If you know what you're doing, feel free to substitute them into the parameters.")
    print("If your path happens to have spaces, make sure it's properly enclosed/escaped for your OS")
    exit(0)
# No help, time to welcome the user
print("Welcome to the yeetpls installer!\nIf you set the '-scripts' flag to a path, we'll download the files there.\nIf you used -default, we'll put them in the usual places.")
print("Naturally, we'll check if we got the right place.")
opts = {'scripts': None}
# Is the default flag set? We'll need this later
default = False
# Guess what OS has been causing trouble. Again. -_-'
windows = False

# Either pick default or the supplied folder. On user error, fuck the user.
if "-default" in argv: # User chose default dirs
    default = True
elif argv[1] == "-scripts":
    opts['scripts'] = argv[2] or 666
    default = True if 666 else False
    print("No path given or incorrect syntax used. Reverting to default.")
else:
    given = input('Please type the absolute or relative path to the MPV scripts directory, defaults to default paths.') or 'default'
    if given.lower() == "default":
        default = True
    else:
        opts['scripts'] = given

if platform.system().lower() == "windows":
    windows = True

if default and not opts['scripts']:
    if windows:
        opts['scripts'] = r"%APPDATA%/mpv/scripts/"
    else:
        opts['scripts'] = "~/.config/mpv/scripts/"

if not opts['scripts'].endswith("/"):
    opts['scripts'] += "/"
opts['scripts'] += "yeetpls/"

if windows:
    # expand %APPDATA%
    opts['scripts'] = opts['scripts'].replace("%APPDATA%", os.getenv('APPDATA'))
    # Replace forwardslashes with double backslashes, because >Windows
    opts['scripts'] = opts['scripts'].replace("/", "\\")
else:
    # expand $HOME
    opts['scripts'] = opts['scripts'].replace("~", os.getenv('$HOME'))

# Confirm that the user agrees to the path
confirmation = input(f"Is the path '{opts['scripts']}' correct? (Yes, it must end in yeetpls) [Y/n]") or "y"
if not confirmation.lower() == "y":
    print("Please run the installer again with the correct path or the '-default' option.")
    exit(1)

# Create any missing directories
Path(opts['scripts']).mkdir(parents=True, exist_ok=True)

# Base URL so we only need to append file names. We'll use str.format in a loop for this
base_url = "https://raw.githubusercontent.com/RivenSkaye/mpv-scripts/master/yeetpls/{}"

# Get the filelist off git
response = req.urlopen(base_url.format("filelist.txt"))
# Make sure we get one file per line, without trailing \r if the file happens to have them.
filelist = response.read().decode(response.headers.get_content_charset()).replace("\r\n", "\n").split("\n")
for line in filelist:
    # Trailing newline be like "HAHA NOPE". Also allows for """comments""" in the file. No idea why I did that.
    if len(line) < 1 or line.startswith('#'):
        # skip empty lines properly. If they somehow end up in the middle, don't die
        continule
    # Fetch the fie
    url = base_url.format(line)
    request = req.urlopen(url)
    # prepare it for directly writing to a file
    content = request.read().decode(response.headers.get_content_charset()).replace("\r\n", "\n")
    if windows: # Keep into account retard OS (Python should handle it, but I don't wanna risk anything here)
        content.replace("\n", "\r\n") # at least we won't get \r\r\n this way
    # Write the file with its proper name. Design of the script depends on this
    with open(opts['scripts']+line, 'w+') as f:
        f.write(content)

# If we get here without errors, we're done. And it's good.
print(f"Should've been successful installing all required files to '{opts['scripts']}'. Thanks for using me and don't forget to run me again for upates!")
# Bedtime
exit(0)
