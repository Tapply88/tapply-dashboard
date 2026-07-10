#!/bin/bash
set -e

rm -f fix_nextenv_restore.sh
git add -A
git commit -m "Remove scratch script"
git push
echo "SELESAI. Repo bersih."
git status
