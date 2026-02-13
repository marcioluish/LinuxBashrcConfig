# Introduction

Contains a collection of bash scripts that setup aliases (git and docker) and prompt configurations for a productive terminal on Linux/WSL.

The `install.sh` script  wires everything into your `~/.bashrc` -- no manual editing needed.

## Features

- **Git-aware prompt** -- current branch shown in PS1 with color-coded segments
- **70+ aliases** -- short commands for Git, Docker, SSH, and system operations
- **Colorized `docker ps`** -- aligned columns, status indicators, port mappings, and container summary
- **Git tab-completion on aliases** -- `go <TAB>` completes branch names just like `git checkout <TAB>`
- **Generic alias completion** -- automatically wires up tab-completion for all aliases pointing to commands that have completions

## Installation
From your HOME directory, run:

```bash
git clone https://github.com/marcioluish/LinuxBashrcConfig.git
bash ~/LinuxBashrcConfig/install.sh
source ~/.bashrc
```

The installer:

1. Resolves its own location (works regardless of where you clone)
2. Backs up your `~/.bashrc` before touching it
3. Exports `BASH_SCRIPTS_DIR` with the resolved path (absolute path appears only once)
4. Adds `source` lines referencing `$BASH_SCRIPTS_DIR`
5. Is idempotent -- safe to run multiple times, skips lines already present
6. If you move the repo, re-run `install.sh` to update the path automatically

## Repository Structure

```
install.sh              # One-command installer
scripts/
├── git-setup.sh        # Git prompt (PS1) and completion framework
├── aliases.sh          # All aliases, functions, and git alias completions
└── docker-ps-color.sh  # Colorized docker container listing
```

## Alias Reference

### Git

| Alias     | Command                | Description                 |
|-----------|------------------------|-----------------------------|
| `st`      | `git status`           | Repository status           |
| `cm`      | `git commit -m`        | Commit with message         |
| `gadd`    | `git add`              | Stage files                 |
| `go`      | `git checkout`         | Switch branches             |
| `pull`    | `git pull`             | Pull from remote            |
| `push`    | `git push`             | Push to remote              |
| `ft`      | `git fetch`            | Fetch from remote           |
| `branch`  | `git branch`           | List/create branches        |
| `merge`   | `git merge`            | Merge branches              |
| `rebase`  | `git rebase`           | Rebase branch               |
| `stash`   | `git stash`            | Stash changes               |
| `reset`   | `git reset`            | Reset HEAD                  |
| `clone`   | `git clone`            | Clone a repository          |
| `restore` | `git restore --staged .` | Unstage all files         |
| `lg`      | `git log --graph ...`  | Pretty one-line log graph   |

All git aliases have full tab-completion (branch names, remotes, etc.).

### Docker -- Containers

| Alias     | Description                                      |
|-----------|--------------------------------------------------|
| `dpsa`    | Colorized `docker ps -a` with aligned columns    |
| `dpsr`    | Running containers in vertical format             |
| `drm`     | `docker rm`                                       |
| `drestart`| `docker restart`                                  |
| `dstart`  | `docker start`                                    |
| `dstop`   | `docker stop`                                     |
| `dit`     | Exec into a container by app name substring       |

### Docker -- Compose

| Alias     | Command               |
|-----------|-----------------------|
| `dcup`    | `docker-compose up`   |
| `dcdown`  | `docker-compose down` |
| `dcbuild` | `docker-compose build`|
| `dckill`  | `docker-compose kill` |

### Docker -- Images, Volumes & Networks

| Alias      | Description                              |
|------------|------------------------------------------|
| `dils`     | `docker image ls`                        |
| `dirm`     | `docker image rm`                        |
| `diclrall` | Remove all images                        |
| `dvls`     | `docker volume ls`                       |
| `dvrm`     | Remove volume(s) by name or pattern      |
| `dvclrall` | Remove all volumes                       |
| `dnls`     | `docker network ls`                      |
| `dnrm`     | `docker network rm`                      |
| `dnclrall` | Remove all networks                      |

### SSH

| Function       | Usage                               | Description                    |
|----------------|-------------------------------------|--------------------------------|
| `createssh`    | `createssh email name password`     | Generate RSA 4096 key          |
| `createsshed`  | `createsshed email name password`   | Generate Ed25519 key           |
| `addssh`       | `addssh keyname`                    | Add key to ssh-agent           |

### System

| Alias              | Description                              |
|--------------------|------------------------------------------|
| `upd`              | `apt update && apt upgrade`              |
| `updatebashrc`     | Reload `~/.bashrc`                       |
| `dockerstart`      | Start Docker daemon via `service`        |
| `dockersocket`     | Fix Docker socket permissions            |
| `systemctlrunning` | List running systemd services            |
| `home`             | `cd $HOME`                               |
| `lls`              | `ls -l`                                  |
| `lnls`             | `ls -ln`                                 |

## docker-ps-color.sh

A standalone script that replaces `docker ps -a` with a more readable, colorized output.

Called via the `dpsa` alias. Extra arguments are forwarded to `docker ps`:

```bash
dpsa                                # all containers
dpsa --filter status=running        # only running
```

What it shows:

- **Aligned columns** -- NAME, IMAGE, STATUS, ID using fixed-width `printf` (no tab drift)
- **Status indicators** -- `●` running (green), `○` exited cleanly (yellow), `✗` error exit (red)
- **Port mappings** -- listed below each container, one per line
- **Summary footer** -- total, running, and stopped counts

Performance notes: uses a single `docker ps` call, pre-builds separator strings outside the loop, and replaces `sed` subprocesses with pure bash string operations.

## Customization

To add your own aliases without modifying tracked files, create `scripts/additional-setup.sh` in the repo directory. If present, it is sourced automatically.
