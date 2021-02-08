"""Interactive installer for Riven's mpv scripts

This interactive installer makes sure to fetch data about the available scripts
in the 'master' branch of the git repository. It then proceeds to offer users
the option to install or update any of the provided scripts in either the
default user folders for mpv, or a folder of their own choosing.

It fetches the information of installed scripts on every start of the script
and only removes entries after installing. This means it may very well list
scripts that are already installed and up-to-date.
Changing this would require changing the behavior of the application and saving
data on the local machine, which is not worth it in my opinion.

Author: RivenSkaye
"""
import urllib.request as req
import json
import os
import platform
from pathlib import Path

print("Welcome to Riven's interactive installer!")

# Guess what OS is causing trouble. Again... -_-'
windows = True if platform.system().lower() == "windows" else False
def_path;
if windows:
    print("I've determined you are on a Windows machine. If this is not the case, something is wrong and you'll have to download the scripts manually.")
    def_path = "%APPDATA%\\mpv\\scripts\\"
else:
    print("I've determined you're on a UNIX-like OS. Thanks for making a somewhat sane decision.")
    def_path = "~.config/mpv/scripts/"
print("Please give me a moment to fetch a list of available scripts. This process is faster on faster internet connections.")
# Base URL so we only need to append file and folder names
base_url = "https://raw.githubusercontent.com/RivenSkaye/mpv-scripts/master/"
filelist = json.loads(req.urlopen(f"{base_url}scripts.json").read().decode(response.headers.get_content_charset()).replace("\r\n", "\n"))



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
