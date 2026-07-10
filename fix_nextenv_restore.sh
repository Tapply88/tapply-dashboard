#!/bin/bash
set -e

echo "=== Balikin next-env.d.ts ==="
git checkout -- next-env.d.ts
echo "OK: next-env.d.ts dipulihkan"

echo ""
echo "=== Commit sisa cleanup (commit_cleanup_dashboard.sh, script lama) ==="
git add -A
git status
git commit -m "Remove old one-off cleanup script"
git push

echo ""
echo "=== SELESAI. ==="
git status
