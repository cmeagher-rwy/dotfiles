#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="${HOME}/.dotfiles"
NODE_VERSION="24"
DRY_RUN=false

# Colors
RESET='\033[0m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'

# ---------- Output ----------

print_status() { printf "${CYAN}%s${RESET}\n" "• $1"; }
print_ok()     { printf "${GREEN}%s${RESET}\n" "  ✓ $1"; }
print_skip()   { printf "${YELLOW}%s${RESET}\n" "  - $1"; }
print_warn()   { printf "${YELLOW}%s${RESET}\n" "  ! $1"; }
print_dry()    { printf "${BLUE}%s${RESET}\n" "  ~ $1"; }

run() {
    if [ "$DRY_RUN" = true ]; then
        print_dry "$1"
        return 0
    fi
    bash -c "$1"
}

# ---------- Helpers ----------

is_cmd() { command -v "$1" &>/dev/null; }

is_apt_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"
}

is_symlinked() {
    local target="$1" expected_source="$2"
    [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$expected_source")" ]
}

# ---------- Sections ----------

update_system() {
    print_status "Updating system packages..."
    run "sudo apt update"
    run "sudo apt upgrade -y"
    print_ok "System packages updated"
}

install_packages() {
    print_status "Installing base packages..."
    local packages=(build-essential curl fonts-jetbrains-mono git stow unzip wget)
    local missing=()

    for pkg in "${packages[@]}"; do
        if ! is_apt_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        print_skip "All base packages are already installed"
        return
    fi
    run "sudo apt install -y ${missing[*]}"
    print_ok "Base packages installed"
}

install_starship() {
    print_status "Installing Starship..."
    if is_cmd starship; then
        print_skip "Starship is already installed"
        return
    fi
    run "curl -sS https://starship.rs/install.sh | sh"
    print_ok "Starship installed"
}

stow_base_dotfiles() {
    print_status "Stowing base dotfiles (bash, git)..."
    if is_symlinked "$HOME/.bashrc" "$DOTFILES_REPO/bash/.bashrc" &&
       is_symlinked "$HOME/.gitconfig" "$DOTFILES_REPO/git/.gitconfig"; then
        print_skip "Base dotfiles (bash, git) are already stowed"
        return
    fi
    run "cd $DOTFILES_REPO && stow --adopt -v bash git"
    if [ "$DRY_RUN" = true ]; then
        print_dry "source $HOME/.bashrc"
    else
        source "$HOME/.bashrc"
    fi
    print_ok "Base dotfiles stowed"
    print_warn "Review any changes with 'git diff' in $DOTFILES_REPO"
}

create_projects_dir() {
    print_status "Creating ~/projects directory..."
    if [ -d "$HOME/projects" ]; then
        print_skip "~/projects directory already exists"
        return
    fi
    run "mkdir -p $HOME/projects"
    print_ok "~/projects directory created"
}

install_gitkraken() {
    print_status "Installing GitKraken..."
    if is_apt_installed gitkraken; then
        print_skip "GitKraken is already installed"
        return
    fi
    run "wget -O /tmp/gitkraken-amd64.deb https://release.gitkraken.com/linux/gitkraken-amd64.deb && sudo apt install -y /tmp/gitkraken-amd64.deb"
    print_ok "GitKraken installed"
    print_warn "Run 'gitkraken' and follow setup steps in gitkraken/README.md"
}

install_node() {
    print_status "Installing fnm, Node $NODE_VERSION, and pnpm..."
    if is_cmd fnm; then
        print_skip "fnm is already installed"
        return
    fi
    run "curl -o- https://fnm.vercel.app/install | bash"
    if [ "$DRY_RUN" = true ]; then
        print_dry "source $HOME/.bashrc"
    else
        source "$HOME/.bashrc"
    fi
    run "fnm install $NODE_VERSION"
    run "corepack enable pnpm"
    print_ok "fnm, Node $NODE_VERSION, and pnpm installed"
}

install_chrome() {
    print_status "Installing Google Chrome..."
    if is_apt_installed google-chrome-stable; then
        print_skip "Google Chrome is already installed"
        return
    fi
    run "wget -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && sudo apt install -y /tmp/google-chrome-stable_current_amd64.deb"
    print_ok "Google Chrome installed"
}

install_opencode() {
    print_status "Installing opencode..."
    if is_cmd opencode; then
        print_skip "opencode is already installed"
        return
    fi
    run "curl -fsSL https://opencode.ai/install | bash"
    print_ok "opencode installed"
}

stow_opencode_dotfiles() {
    print_status "Stowing opencode dotfiles (agents, opencode)..."
    if is_symlinked "$HOME/.agents/skills/find-docs/SKILL.md" "$DOTFILES_REPO/agents/.agents/skills/find-docs/SKILL.md" &&
       is_symlinked "$HOME/.config/opencode/opencode.jsonc" "$DOTFILES_REPO/opencode/.config/opencode/opencode.jsonc"; then
        print_skip "opencode dotfiles (agents, opencode) are already stowed"
        return
    fi
    run "cd $DOTFILES_REPO && stow --adopt -v agents opencode"
    print_ok "opencode dotfiles stowed"
    print_warn "Review any changes with 'git diff' in $DOTFILES_REPO"
}

# ---------- Main ----------

main() {
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=true ;;
            -h|--help)
                echo "Usage: $0 [--dry-run]"
                echo ""
                echo "Automates the Debian setup described in linux/README.md."
                echo "Idempotent — safe to run multiple times."
                exit 0
                ;;
        esac
    done

    echo ""
    printf "${BOLD}dotfiles installer${RESET}\n"
    [ "$DRY_RUN" = true ] && printf "${BLUE}Dry-run mode — no changes will be made${RESET}\n"
    echo ""

    # Keep sudo credentials alive: prompt once at start, then refresh every 60s
    # The background loop exits automatically when this script process ends
    if [ "$DRY_RUN" = false ]; then
        sudo -v
        while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    fi

    update_system
    install_packages
    install_starship
    stow_base_dotfiles
    create_projects_dir
    install_gitkraken
    install_node
    install_chrome
    install_opencode
    stow_opencode_dotfiles

    echo ""
    printf "${GREEN}✨ ${BOLD}Done.${RESET}\n"

    # source in a subshell only affects the subshell, so the user must reload
    # in their own terminal to pick up aliases, fnm PATH, starship, etc.
    printf "${BOLD}  → Run 'source ~/.bashrc' to reload your shell.${RESET}\n"
}

main "$@"
