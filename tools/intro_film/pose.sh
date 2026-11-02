#!/bin/bash
# usage: pose.sh out.png 'json'
n=$(python3 -c "import json,sys;print(len(json.loads(sys.argv[1])))" "$2")
node /home/claude/oddo-intro/shot.mjs "poses.html#$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$2")" "$1" $((360*n)) 460 2>&1 | grep -v 404
