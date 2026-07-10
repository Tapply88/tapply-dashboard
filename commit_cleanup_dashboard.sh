#!/bin/bash
set -e

echo "=== Add semua perubahan ==="
git add -A

echo ""
echo "=== Commit ==="
git commit -m "Clean up scratch scripts from root, update .gitignore"

echo ""
echo "=== Push ==="
git push

echo ""
echo "=== SELESAI. Repo tapply-dashboard udah bersih. ==="
git status
