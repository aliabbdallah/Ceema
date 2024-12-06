#!/usr/bin/osascript
tell application "Terminal"
    activate
    do script ". /Users/AliA/anaconda3/bin/activate && conda activate /Users/AliA/anaconda3/envs/bigData; "
end tell
