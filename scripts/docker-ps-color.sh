#!/bin/bash
# docker-ps-color.sh — Colorized, column-aligned docker container listing
#
# Usage: docker-ps-color.sh [docker-ps options]
# Extra arguments are forwarded to 'docker ps -a'.
#   e.g.  docker-ps-color.sh --filter status=running
#
# Status indicators:
#   ● running (green)    ○ stopped (yellow)    ✗ error (red)
#   ↻ restarting (yellow)  ⏸ paused (blue)    ◌ created (gray)

# ── Colors ────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;96m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# ── Column widths ─────────────────────────────────────────────
W_NAME=25
W_IMAGE=50
W_STATUS=32
W_ID=12
TOTAL_W=$(( W_NAME + W_IMAGE + W_STATUS + W_ID + 6 ))

# Pre-build separator string once (avoids repeated subshells in the loop)
SEP=$(printf '%*s' "$TOTAL_W" '' | tr ' ' '─')

# ── Fetch container data (single docker call) ────────────────
# State is placed before Ports so that empty Ports (last field)
# never shifts State out of position.
data=$(docker ps -a "$@" \
    --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.ID}}\t{{.State}}\t{{.Ports}}')

if [[ -z "$data" ]]; then
    printf "\n ${YELLOW}No containers found.${NC}\n\n"
    exit 0
fi

# ── Count totals (no extra docker calls) ──────────────────────
# Categories: running, stopped (normal exit), errors (abnormal exit / dead)
total=0 running=0 stopped=0 errors=0
while IFS=$'\t' read -r _ _ status _ state _; do
    (( total++ ))
    case "$state" in
        running|restarting)
            (( running++ )) ;;
        dead)
            (( errors++ )) ;;
        exited)
            # 0 = clean, 137 = SIGKILL, 143 = SIGTERM → normal docker stop
            if [[ "$status" == *"(0)"* || "$status" == *"(137)"* || "$status" == *"(143)"* ]]; then
                (( stopped++ ))
            else
                (( errors++ ))
            fi ;;
        *)  # paused, created, removing
            (( stopped++ )) ;;
    esac
done <<< "$data"

# ── Header ────────────────────────────────────────────────────
printf "\n"
printf " ${BOLD}%-${W_NAME}s  %-${W_IMAGE}s  %-${W_STATUS}s  %-${W_ID}s${NC}\n" \
    "NAME" "IMAGE" "STATUS" "ID"
printf " ${GRAY}${SEP}${NC}\n"

# ── Rows ──────────────────────────────────────────────────────
while IFS=$'\t' read -r name image status id state ports; do
    # Smart image name: strip registry domain, show full reference on a second line
    full_image="$image"
    display_image="$image"
    image_stripped=false

    if [[ "$image" == */* ]]; then
        prefix="${image%%/*}"
        if [[ "$prefix" == *.* || "$prefix" == *:* ]]; then
            display_image="${image#*/}"
            image_stripped=true
        fi
    fi

    if (( ${#display_image} > W_IMAGE )); then
        display_image="${display_image:0:$(( W_IMAGE - 3 ))}..."
    fi

    # Color & indicator by container state (Option B: exit-code aware)
    #   running           → green ●       restarting → yellow ↻
    #   exited 0/137/143  → yellow ○      paused     → blue ⏸
    #   exited (other)    → red ✗         created    → gray ◌
    #   dead              → red ✗
    case "$state" in
        running)     color="$GREEN"  ; icon="●" ;;
        restarting)  color="$YELLOW" ; icon="↻" ;;
        paused)      color="$BLUE"   ; icon="⏸" ;;
        created)     color="$GRAY"   ; icon="◌" ;;
        dead)        color="$RED"    ; icon="✗" ;;
        exited)
            if [[ "$status" == *"(0)"* || "$status" == *"(137)"* || "$status" == *"(143)"* ]]; then
                color="$YELLOW" ; icon="○"
            else
                color="$RED"    ; icon="✗"
            fi ;;
        *)           color="$GRAY"   ; icon="…" ;;
    esac

    # Main row
    printf " ${color}%-${W_NAME}.${W_NAME}s${NC}  %-${W_IMAGE}.${W_IMAGE}s  ${color}%s %-$(( W_STATUS - 2 )).$(( W_STATUS - 2 ))s${NC}  ${GRAY}%s${NC}\n" \
        "$name" "$display_image" "$icon" "$status" "$id"

    # Full image reference (only when the registry was stripped)
    if [[ "$image_stripped" == true ]]; then
        printf " ${GRAY}%-${W_NAME}s  ↳ %s${NC}\n" "" "$full_image"
    fi

    # Port mappings (indented, one per line)
    if [[ -n "$ports" ]]; then
        IFS=',' read -ra port_arr <<< "$ports"
        for p in "${port_arr[@]}"; do
            p="${p#"${p%%[![:space:]]*}"}"
            printf " ${BLUE}%-${W_NAME}s  ↳ %s${NC}\n" "" "$p"
        done
    fi

    printf " ${GRAY}${SEP}${NC}\n"
done <<< "$data"

# ── Summary footer ────────────────────────────────────────────
printf "\n ${CYAN}${BOLD}%d${NC} ${CYAN}containers${NC}" "$total"
printf "  │  ${GREEN}${BOLD}%d${NC} ${GREEN}running${NC}" "$running"
printf "  │  ${YELLOW}${BOLD}%d${NC} ${YELLOW}stopped${NC}" "$stopped"
if (( errors > 0 )); then
    err_s=""; (( errors > 1 )) && err_s="s"
    printf "  │  ${RED}${BOLD}%d${NC} ${RED}error%s${NC}" "$errors" "$err_s"
fi
printf "\n\n"
