"""Interactive installer for Riven's mpv scripts

This interactive installer makes sure to fetch data about the available scripts
in the 'master' branch of the git repository. It then proceeds to offer users
the option to install or update any of the provided scripts in either the
default user folders for mpv, or a folder of their own choosing.

It fetches the information of available scripts on every start
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
from typing import Dict

print("Welcome to Riven's interactive installer!\n")

# Guess what OS is causing trouble. Again... -_-'
windows = True if "windows" in platform.system().lower() else False
def_path = None;
sep = None
stop = False

if windows:
    print("I've determined you are on a Windows machine. If this is not the case,\n\tsomething is wrong and you'll have to download the scripts manually.\n")
    def_path = f"{os.getenv('APPDATA')}\\mpv\\scripts\\"
    sep = "\\"
else:
    print("I've determined you're on a UNIX-like OS. Thanks for making a somewhat sane decision.")
    def_path = f"{os.getenv('$HOME')}/.config/mpv/scripts/"
    sep = "/"

print("Please give me a moment to fetch a list of available scripts...\n")
# Base URL so we only need to append file and folder names
base_url = "https://raw.githubusercontent.com/RivenSkaye/mpv-scripts/master/"
jsonreq = req.urlopen(f"{base_url}scripts.json")
filelist = json.loads(jsonreq.read().decode(jsonreq.headers.get_content_charset()).replace("\r\n", "\n"))

def select_script(filelist):
    if len(filelist.keys()) < 1:
        return True
    choices = ["[0] Default: Intstall all scripts"]
    keys = []
    curnum = 1
    for key in filelist:
        choices.append(f"[{curnum}] Install {key}")
        keys.append(key)
        curnum = curnum + 1
    choices.append("[-1] Stop selecting scripts and exit")
    choices = '\n'.join(choices)
    reply = int(input(f"Please select what script(s) to install: \n{choices}\n\n> ") or 0)
    if reply > 0:
        install_script(filelist[keys[reply-1]], keys[reply-1])
        del filelist[keys[reply-1]]
        return False
    if reply < 0: # You know who you are that this is warranted :ogsmug:
        return True
    else:
        for key in filelist:
            install_script(filelist[key], key)
        return True


def install_script(data: Dict, name: str):
    url = data['base_url']
    if len(data['optional']) > 0:
        joiner = "\n - "
        opts = input(f"There are optional script files:{joiner}{joiner.join(data['optional'])}\nThese are recommended to have, would you like to install these? [Y/n]\n\n> ") or 'y'
    targets = data['required'] + data['optional'] if opts.lower().startswith('y') else data['required']
    out_path = input(f"Please provide the full path for your mpv scripts directory.\nJust hit enter if {def_path} is fine.\n\n> ") or def_path
    if not out_path.endswith(sep):
        out_path += sep
    if data['multifile']:
        out_path += f"{name}{sep}"
    Path(out_path).mkdir(parents=True, exist_ok=True)
    for t in targets:
        scriptfile = f"{out_path}{t}"
        scriptreq = req.urlopen(url+t)
        content = scriptreq.read().decode(scriptreq.headers.get_content_charset()).replace("\r", "").split('\n')
        to_file = []
        with open(scriptfile, "w+") as f:
            f.write('\n'.join(content))
    return

while not select_script(filelist): pass

# If we get here without errors, we're done. And it's good.
print(f"\nShould've been successful installing all requested scripts. Thanks for using me and don't forget to run me again for updates!")
# Bedtime
exit(0)
