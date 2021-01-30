import urllib.request as req
# Base URL so we only need to append file names. We'll use format in a loop for this
base_url = "https://raw.githubusercontent.com/RivenSkaye/mpv-scripts/master/yeetpls/{}"
response = req.urlopen(base_url.format("filelist.txt"))
filelist = response.read().decode(response.headers.get_content_charset()).replace("\r\n", "\n").split("\n")

