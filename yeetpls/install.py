import urllib.request as req
import sys
import platform
from pathlib import Path
import os

argv = sys.argv
helps = ['-h', '-help', '--h', '--help']
if any([h == a for h in helps for a in argv]) or len(argv) <= 1:
    print("Installs the yeetpls user script for mpv. Valid options are:")
    print("-default\t\tUses the default user-based scripts dir for this user. If this is supplied, specified folders get ignored.")
    print("-scripts <path/to/scripts/folder>\tSpecify a folder.")
    print("-h, -help, --h, --help\tSummons this message and exits. If this is present, all other options will be ignored.")
    exit(0)
print("Welcome to the yeetpls installer! If you set the '-scripts' flag to a path, we'll download the files there. If you didn't, please input it now.")
opts = {'scripts': None}
default = False
windows = False
if "-default" in argv: # User chose default dirs
    default = True
elif argv[1] == "-scripts":
    opts['scripts'] = argv[2]
else:
    given = input('Please type the absolute or relative path to the MPV scripts directory, or default to go with OS defaults.')
    if given == "default":
        default = True

if platform.system().lower() == "windows":
    windows = True

if default and not opts['scripts']:
    if windows:
        opts['scripts'] = r"%APPDATA%/mpv/scripts/"
    else:
        opts['scripts'] = "~/.config/mpv/scripts/"

if windows: # honestly, this OS is a pain to deal with
    opts['scripts'] = opts['scripts'].replace("%APPDATA%", os.getenv('APPDATA'))
    opts['scripts'] = opts['scripts'].replace("/", "\\")
else:
    opts['scripts'] = opts['scripts'].replace("~", os.getenv('$HOME'))

if not opts['scripts'].endswith("/"):
    opts['scripts'] += "/"
opts['scripts'] += "yeetpls/"

Path(opts['scripts']).mkdir(parents=True, exist_ok=True)
# Base URL so we only need to append file names. We'll use format in a loop for this
base_url = "https://raw.githubusercontent.com/RivenSkaye/mpv-scripts/yeetpls-installer/yeetpls/{}"

response = req.urlopen(base_url.format("filelist.txt"))
filelist = response.read().decode(response.headers.get_content_charset()).replace("\r\n", "\n").split("\n")
for line in filelist:
    if len(line) < 1 or line.startswith('#'):
        continue
    url = base_url.format(line)
    request = req.urlopen(url)
    content = request.read().decode(response.headers.get_content_charset()).replace("\r\n", "\n")
    if windows:
        content.replace("\n", "\r\n") # at least we won't get \r\r\n this way
    with open(opts['scripts']+line, 'w+') as f:
        f.write(content)

print(f"Should've been successful installing all required files to '{opts['scripts']}'. Thanks for using me and don't forget to run me again for upates!")
exit(0)
