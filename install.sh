#!/bin/bash
# Installer script for bashrc.d setup
# Appends source lines to ~/.bashrc for git-setup.sh and aliases.sh
# Idempotent: safe to run multiple times (skips lines already present)
#
# Usage: bash /path/to/install.sh
# The script auto-detects the scripts/ folder relative to its own location.

set -euo pipefail

BASHRC="$HOME/.bashrc"

# Resolve the directory where this install.sh lives (works even if called via symlink)
INSTALL_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
SCRIPTS_DIR="$INSTALL_DIR/scripts"

echo "=== running installer ==="
echo "Repo location: $INSTALL_DIR"
echo "Scripts dir:   $SCRIPTS_DIR"
echo "Target:        $BASHRC"
echo ""

# Verify scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo "ERROR: $SCRIPTS_DIR not found."
    echo "Expected a 'scripts/' folder next to install.sh."
    exit 1
fi

# Verify committable script files exist
missing=0
for script in git-setup.sh aliases.sh; do
    if [ ! -f "$SCRIPTS_DIR/$script" ]; then
        echo "ERROR: $SCRIPTS_DIR/$script not found."
        missing=1
    fi
done
if [ "$missing" -eq 1 ]; then
    echo "Aborting. Please check your repo contents."
    exit 1
fi

# Backup .bashrc before modifying
backup="${BASHRC}.bak.$(date +%Y%m%d%H%M%S)"
cp "$BASHRC" "$backup"
echo "Backup created: $backup"
echo ""

# --- Inject or update BASH_SCRIPTS_DIR export ---
# This single variable holds the absolute path to the scripts directory.
# All source lines below reference it, so the absolute path appears only once.
EXPORT_LINE="export BASH_SCRIPTS_DIR=\"$SCRIPTS_DIR\""

if grep -qF "BASH_SCRIPTS_DIR" "$BASHRC"; then
    # Update existing export (handles the case where the repo was moved)
    sed -i "s|^export BASH_SCRIPTS_DIR=.*|$EXPORT_LINE|" "$BASHRC"
    echo "[UPDATED] BASH_SCRIPTS_DIR -> $SCRIPTS_DIR"
else
    echo "" >> "$BASHRC"
    echo "# Scripts directory (set by install.sh)" >> "$BASHRC"
    echo "$EXPORT_LINE" >> "$BASHRC"
    echo "[ADDED] BASH_SCRIPTS_DIR -> $SCRIPTS_DIR"
fi

# --- Migrate old hardcoded paths to use $BASH_SCRIPTS_DIR ---
# Safe to run multiple times; only matches lines still using absolute paths.
for suffix in git-setup.sh aliases.sh additional-setup.sh; do
    sed -i 's|"'"$SCRIPTS_DIR/$suffix"'"|"$BASH_SCRIPTS_DIR/'"$suffix"'"|g' "$BASHRC"
done
echo "[MIGRATED] Replaced any hardcoded paths with \$BASH_SCRIPTS_DIR"

# Lines to inject (committable files only)
# Each entry: "marker_to_grep|full_line_to_append"
# Source lines use $BASH_SCRIPTS_DIR (set above) instead of hardcoded paths.
ENTRIES=(
    "scripts/git-setup.sh|# Source git prompt, aliases, and completions
[ -f \"\$BASH_SCRIPTS_DIR/git-setup.sh\" ] && . \"\$BASH_SCRIPTS_DIR/git-setup.sh\""
    "scripts/aliases.sh|# Source general aliases and utility functions
[ -f \"\$BASH_SCRIPTS_DIR/aliases.sh\" ] && . \"\$BASH_SCRIPTS_DIR/aliases.sh\""
    "alias_completion|# Wire up completions for all aliases (function defined in git-setup.sh)
type alias_completion &>/dev/null && alias_completion"
)

# Inject each entry if not already present
for entry in "${ENTRIES[@]}"; do
    marker="${entry%%|*}"
    block="${entry#*|}"

    if grep -qF "$marker" "$BASHRC"; then
        echo "[SKIP] Already present: $marker"
    else
        echo "" >> "$BASHRC"
        echo "$block" >> "$BASHRC"
        echo "[ADDED] $marker"
    fi
done

echo ""
echo "Done. Run 'source ~/.bashrc' or open a new terminal to apply changes."
