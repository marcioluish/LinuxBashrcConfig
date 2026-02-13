#!/bin/bash
# General aliases and utility functions

# Use BASH_SCRIPTS_DIR if set by install.sh, otherwise resolve from this script's location
_ALIASES_SCRIPT_DIR="${BASH_SCRIPTS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# --- Docker format variable ---
# Used by the dpsr alias below (not related to docker-ps-color.sh which has its own format)
export VERTICAL="\nNames\t{{.Names}}\t\tCreated\t{{.RunningFor}}\t\tStatus\t{{.Status}}\nImage\t{{.Image}}\nPorts\t{{.Ports}}"

# --- env aliases ---
alias upd="sudo apt update && sudo apt upgrade"
alias gitconfig="code ~/.ssh/config"
alias lls="ls -l"
alias lnls="ls -ln"
alias rmzoneid="find . -name "*Zone.Identifier" -type f -delete"

# --- Navigation aliases ---
alias home="cd $HOME"

# --- Command aliases ---
alias updatebashrc=". ~/.bashrc"
alias dockersocket="sudo chmod 666 /var/run/docker.sock"
alias dockerstart="sudo service docker start"
alias systemctlrunning="systemctl list-units --type=service --state=running"

# --- Git aliases ---
alias cm="git commit -m"
alias ft="git fetch"
alias gadd="git add"
alias go="git checkout"
alias lg="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias pull="git pull"
alias push="git push"
alias rebase="git rebase"
alias reset="git reset"
alias st="git status"
alias stash="git stash"
alias merge="git merge"
alias clone="git clone"
alias branch="git branch"
alias restore="git restore --staged ."

# Git alias completions (requires git-setup.sh to have loaded git completions first)
if type __git_complete &>/dev/null; then
    __git_complete go _git_checkout
    __git_complete stash _git_stash
    __git_complete pull _git_pull
    __git_complete push _git_push
    __git_complete reset _git_reset
    __git_complete rebase _git_rebase
    __git_complete clone _git_clone
    __git_complete branch _git_branch
fi

# --- Docker aliases ---
alias dpsa="$_ALIASES_SCRIPT_DIR/docker-ps-color.sh"
alias dpsr='docker ps -a --filter status=running --format=$VERTICAL'
alias dcup='docker-compose up'
alias dcdown='docker-compose down'
alias dcbuild='docker-compose build'
alias dckill='docker-compose kill'
alias diclrall='docker image rm $(docker images ls)'
alias dirm='docker image rm'
alias dils='docker image ls'
alias dvls='docker volume ls'
alias dvclrall='docker volume rm $(docker volume ls)'
alias drm='docker rm'
alias drestart='docker restart'
alias dstart='docker start'
alias dstop='docker stop'
alias dnls='docker network ls'
alias dnrm='docker network rm'
alias dnclrall='docker network rm $(docker network ls)'

# --- SSH functions ---
createssh() {
    # $1 = email
    # $2 = key name
    # $3 = key password
    ssh-keygen \
        -m PEM \
        -t rsa \
        -b 4096 \
        -C "$1" \
        -f ~/.ssh/"$2" \
        -N "$3"
}

createsshed() {
    # $1 = email
    # $2 = key name
    # $3 = key password
    ssh-keygen \
        -t ed25519 \
        -C "$1" \
        -f ~/.ssh/"$2" \
        -N "$3"
}

addssh() {
    # $1 = key name
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/"$1"
}

# --- Docker Functions ---
dit() {
    # Usage: dit <application>
    # Example: dit ict
    local app="$1"
    if [[ -z "$app" ]]; then
        echo "Usage: dit <application>"
        return 1
    fi

    local container
    container=$(docker ps -a --format '{{.Names}}' | grep -- "-${app}-" | head -n 1)
    if [[ -z "$container" ]]; then
        echo "No container found matching '-${app}-'"
        return 1
    fi
    docker exec -it "$container" bash
}

dvrm() {
    # Usage: dvrm <volume_name_or_pattern>
    # 1) If a volume with the exact name exists, remove it.
    # 2) Otherwise, remove all volumes whose names contain the input as a substring.
    local input="$1"
    if [[ -z "$input" ]]; then
        echo "Usage: dvrm <volume_name_or_pattern>"
        return 1
    fi

    # Check for exact match
    if docker volume ls --format '{{.Name}}' | grep -Fxq "$input"; then
        docker volume rm "$input"
    else
        # Find all volumes containing the input as a substring
        local matches
        matches=$(docker volume ls --format '{{.Name}}' | grep -- "$input")
        if [[ -z "$matches" ]]; then
            echo "No volumes found matching: $input"
            return 1
        fi
        echo "Removing volumes:"
        echo "$matches"
        docker volume rm $matches
    fi
}
