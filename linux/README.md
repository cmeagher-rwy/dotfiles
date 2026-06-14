# linux

These setup instructions are for Debian.

> N.B. See [linux tips](#linux-tips) for some general help with common operations.

## Automated setup

The [`install.sh`](../install.sh) script automates the full setup:

```bash
# Preview what will be done
./install.sh --dry-run

# Run the installer (idempotent — safe to run multiple times)
./install.sh

# Reload your shell (using an alias)
reload
```

> The script must be run from within the cloned `~/.dotfiles` directory.
> It is idempotent: completed steps are skipped on re-run.

## Manual setup

### System packages

* Update distro
  * `sudo apt update && sudo apt upgrade -y` - update distro
* Install packages
  * `sudo apt install build-essential curl fonts-jetbrains-mono git stow unzip wget -y`

### Starship

* Install [Starship](https://starship.rs/)
  * `curl -sS https://starship.rs/install.sh | sh`

### Dotfiles (base)

* Clone the repo
  * `git clone https://github.com/CMeeg/dotfiles.git ~/.dotfiles`
* Link dotfiles
  * `cd ~/.dotfiles`
  * `stow --adopt -v bash git starship`
  * Accept or reject changes to dotfiles (if any)
    * View the diff of the dotfiles repo
    * Accept/merge/reject changes
    * Commit and push, if needed
* Reload bash profile
  * `source ~/.bashrc`
* Create `projects` directory
  * `mkdir ~/projects`

### GitKraken

* Install GitKraken Client
  * `cd /tmp`
  * `wget https://release.gitkraken.com/linux/gitkraken-amd64.deb`
  * `sudo apt install ./gitkraken-amd64.deb -y`
* Run `gitkraken`
* Follow the [setup steps](./gitkraken/README.md)

### Node

* [Install Node](https://nodejs.org/en/download)
  * `curl -o- https://fnm.vercel.app/install | bash` - install fnm
  * `reload` - reload bash (using alias)
  * `fnm install 24` - or whatever version you want
  * `node -v` - verify node is installed
* Enable pnpm
  * `corepack enable pnpm` - enable pnpm
  * `pnpm -v` - verify pnpm available

### Chrome

* Install Chrome
  * `cd /tmp`
  * `wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb`
  * `sudo apt install ./google-chrome-stable_current_amd64.deb -y`

> N.B. Chrome can be launched from wsl if needed by running `google-chrome`

### OpenCode

* Install [opencode](https://opencode.ai/docs/windows-wsl)
  * `curl -fsSL https://opencode.ai/install | bash`
  * `reload` - reload bash (using alias)
* Link dotfiles
  * `cd ~/.dotfiles`
  * `stow --adopt -v agents opencode`
  * Accept or reject changes to dotfiles (if any)
    * View the diff of the dotfiles repo
    * Accept/merge/reject changes
    * Commit and push, if needed
* Run `opencode`
* Run `/connect` and connect a provider

## linux tips

* If you need to kill a program
  * `pidof <program>` - find pid(s) of program
  * `kill -<signal> <pid(s)>` - send kill signal to pid(s), `15` is SIGTERM, `9` is SIGKILL
