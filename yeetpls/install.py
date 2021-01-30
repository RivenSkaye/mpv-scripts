import urllib.request as req
import sys.argv as argv
import platform

helps = ['-h', '-help', '--h', '--help']
if any([h == a for h in helps for a in argv]):
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

if default and not opts['scripts']:
    if platform.system().lower() == "windows":
        opts['scripts'] = "%APPDATA%/mpv/scripts/"
    else:
        opts['scripts'] = "~/.config/mpv/scripts/"

if not opts['scripts'].endswith("/"):
    opts['scripts'] += "/"
if windows:
    opts['scripts'] = opts['scripts'].replace("/", "\\")
# Base URL so we only need to append file names. We'll use format in a loop for this
base_url = "https://raw.githubusercontent.com/RivenSkaye/mpv-scripts/yeetpls-installer/yeetpls/{}"

response = req.urlopen(base_url.format("filelist.txt"))
filelist = response.read().decode(response.headers.get_content_charset()).replace("\r\n", "\n").split("\n")
for line in filelist:
    url = base_url.format(line)
    request = req.urlopen(url)
    content = request.read().decode(response.headers.get_content_charset()).replace("\r\n", "\n").split("\n")
    with open(opts['scripts']+line) as f:
        f.writelines(content)
