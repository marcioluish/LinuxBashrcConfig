#!/bin/bash
# Installer script for LinuxBashrcConfig
# Writes a managed block into ~/.bashrc (idempotent: replaces block on re-run)
#
# Usage:
#   bash /path/to/install.sh              # current user only
#   bash /path/to/install.sh --user root  # single user by name
#   bash /path/to/install.sh --all-users  # root + every /home/* user
#
# The script auto-detects the scripts/ folder relative to its own location.

set -euo pipefail

BEGIN_MARKER="# >>> LinuxBashrcConfig >>>"
END_MARKER="# <<< LinuxBashrcConfig <<<"

# Resolve the directory where this install.sh lives (works even if called via symlink)
INSTALL_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
SCRIPTS_DIR="$INSTALL_DIR/scripts"

usage() {
    cat <<EOF
Usage: bash $0 [OPTIONS]

Options:
  (none)        Install for the current user (\$HOME/.bashrc)
  --user NAME   Install for a specific user (e.g. --user root)
  --all-users   Install for root and every user under /home/* with a .bashrc
  -h, --help    Show this help

Examples:
  bash $0
  bash $0 --user root
  sudo bash $0 --all-users
EOF
}

remove_managed_block() {
    local bashrc="$1"
  local tmp
  tmp="$(mktemp)"

  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == begin { skip=1; next }
    $0 == end   { skip=0; next }
    !skip { print }
  ' "$bashrc" > "$tmp"

  mv "$tmp" "$bashrc"
}

remove_legacy_lines() {
    local bashrc="$1"
  local tmp
  tmp="$(mktemp)"

  grep -vE \
    -e '^# Scripts directory \(set by (install\.sh|bash-scripts/install\.sh)\)$' \
    -e '^export BASH_SCRIPTS_DIR=' \
    -e '^# Source additional aliases$' \
    -e '^# Source git prompt, aliases, and completions$' \
    -e '^# Source general aliases and utility functions$' \
    -e '^# Wire up completions for all aliases \(function defined in git-setup\.sh\)$' \
    -e '^\[ -f "\$BASH_SCRIPTS_DIR/(additional-setup|git-setup|aliases)\.sh" \] && \. "\$BASH_SCRIPTS_DIR/(additional-setup|git-setup|aliases)\.sh"$' \
    -e '^type alias_completion &>/dev/null && alias_completion$' \
    "$bashrc" > "$tmp" 2>/dev/null || cp "$bashrc" "$tmp"

  # Drop trailing blank lines left after legacy removal
  awk '/./{blank=0} !/./{blank++} blank<2' "$tmp" > "${tmp}.trim"
  mv "${tmp}.trim" "$bashrc"
  rm -f "$tmp"
}

write_managed_block() {
    local bashrc="$1"
  local export_line="export BASH_SCRIPTS_DIR=\"$SCRIPTS_DIR\""

  {
    echo ""
    echo "$BEGIN_MARKER"
    echo "$export_line"
    echo '[ -f "$BASH_SCRIPTS_DIR/additional-setup.sh" ] && . "$BASH_SCRIPTS_DIR/additional-setup.sh"'
    echo '[ -f "$BASH_SCRIPTS_DIR/git-setup.sh" ] && . "$BASH_SCRIPTS_DIR/git-setup.sh"'
    echo '[ -f "$BASH_SCRIPTS_DIR/aliases.sh" ] && . "$BASH_SCRIPTS_DIR/aliases.sh"'
    echo "type alias_completion &>/dev/null && alias_completion"
    echo "$END_MARKER"
  } >> "$bashrc"
}

install_for_bashrc() {
    local bashrc="$1"
  local label="$2"
  local owner="${3:-}"

  if [ ! -f "$bashrc" ]; then
    echo "[$label] SKIP: $bashrc not found"
    return 0
  fi

  local backup="${bashrc}.bak.$(date +%Y%m%d%H%M%S)"
  cp "$bashrc" "$backup"
  echo "[$label] Backup: $backup"

  remove_managed_block "$bashrc"
  remove_legacy_lines "$bashrc"
  write_managed_block "$bashrc"

  if [ -n "$owner" ] && [ "$(id -u)" -eq 0 ]; then
    chown "$owner:$owner" "$bashrc" "$backup"
  fi

  echo "[$label] Installed managed block -> $bashrc"
}

resolve_user_bashrc() {
    local username="$1"
  if [ "$username" = "root" ]; then
    echo "/root/.bashrc"
  elif [ -d "/home/$username" ]; then
    echo "/home/$username/.bashrc"
  else
    echo ""
  fi
}

# --- Parse arguments ---
MODE="current"
TARGET_USER=""

while [ $# -gt 0 ]; do
    case "$1" in
        --all-users)
            MODE="all"
            shift
            ;;
        --user)
            MODE="user"
            TARGET_USER="${2:-}"
            if [ -z "$TARGET_USER" ]; then
                echo "ERROR: --user requires a username."
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

echo "=== LinuxBashrcConfig installer ==="
echo "Repo location: $INSTALL_DIR"
echo "Scripts dir:   $SCRIPTS_DIR"
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

# --- Install for target(s) ---
case "$MODE" in
    current)
        install_for_bashrc "$HOME/.bashrc" "$(whoami)" "$(whoami)"
        ;;
    user)
        bashrc="$(resolve_user_bashrc "$TARGET_USER")"
        if [ -z "$bashrc" ]; then
            echo "ERROR: No home directory found for user '$TARGET_USER'."
            exit 1
        fi
        install_for_bashrc "$bashrc" "$TARGET_USER" "$TARGET_USER"
        ;;
    all)
        install_for_bashrc "/root/.bashrc" "root" "root"

        for homedir in /home/*; do
            [ -d "$homedir" ] || continue
            username="$(basename "$homedir")"
            bashrc="$homedir/.bashrc"
            install_for_bashrc "$bashrc" "$username" "$username"
        done
        ;;
esac

echo ""
echo "Done. Run 'source ~/.bashrc' or open a new terminal to apply changes."
