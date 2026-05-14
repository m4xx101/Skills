#!/usr/bin/env bash
set -euo pipefail

echo "Dokploy Skill Suite — Installer"
echo "========================================"
echo ""

SKILLS_DIR="${HERMES_SKILLS_DIR:-$HOME/.hermes/skills/devops}"
TARGET="$SKILLS_DIR/dokploy"
TMPDIR=$(mktemp -d)

# Determine source: local script or piped from web
if [[ "$0" == "bash" ]] || [[ "$0" == "/dev/stdin" ]]; then
    # piped via curl | bash — clone the repo
    echo "Detected piped install — cloning from GitHub..."
    git clone --depth 1 https://github.com/m4xx101/dokploy-skills.git "$TMPDIR/repo"
    SOURCE="$TMPDIR/repo"
else
    SOURCE="$(cd "$(dirname "$0")" && pwd)"
fi

mkdir -p "$TARGET"

# Copy all skill files (skip .git, installer scripts)
echo "Installing to $TARGET"
find "$SOURCE" -maxdepth 1 -type f \( -name "*.md" -o -name ".gitignore" \) -exec cp {} "$TARGET/" \;
for dir in "$SOURCE"/*/; do
    dirname=$(basename "$dir")
    [[ "$dirname" == ".git" ]] && continue
    cp -r "$dir" "$TARGET/"
done

# Cleanup temp if we cloned
[[ -n "${TMPDIR:-}" ]] && rm -rf "$TMPDIR"

echo ""
echo "Done."
echo ""
echo "Next steps:"
echo "  1. export DOKPLOY_API_KEY='your-key-here'"
echo "  2. In Hermes: /dokploy"
echo ""
echo "Docs: https://github.com/m4xx101/dokploy-skills"
