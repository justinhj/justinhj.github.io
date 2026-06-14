#!/bin/bash

# Exit cleanly on Ctrl+C
trap "exit" INT

echo "Watching Org files for changes... (Press Ctrl+C to stop)"

while true; do
  find org -name "*.org" | entr -d /Applications/Emacs.app/Contents/MacOS/Emacs --batch --load org/publish.el --eval '(org-publish "all")'
done
