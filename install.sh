#!/bin/bash
# ---------------------------------------------------------------------------
# | pavkam's .dotfiles installation script.                                 |
# |                                                                         |
# | No warranties are provided, no responsibility is taken. You're on your  |
# | own! I will recommend you backup your home before trying this script.   |
# ---------------------------------------------------------------------------

# ============================================================================
# Constants and Configuration
# ============================================================================

# Paths
LOG_FILE="$HOME/.dotfiles.log"
BACKUP_DIR="$HOME/.dotfiles.backup"
DOTFILES_SCRIPT_PATH=$(realpath "$0")
DOTFILES_DIR=$(dirname "$DOTFILES_SCRIPT_PATH")

# Git repositories
OH_MY_ZSH_GIT_REPO="https://github.com/ohmyzsh/ohmyzsh.git"
POWER_LEVEL_10K_GIT_REPO="https://github.com/romkatv/powerlevel10k.git"
ZSH_AUTO_SUGGESTIONS_GIT_REPO="https://github.com/zsh-users/zsh-autosuggestions"
ZSH_HISTORY_SUBSTRING_GIT_REPO="https://github.com/zsh-users/zsh-history-substring-search"
ZSH_SYNTAX_HIGHLIGHTING_GIT_REPO="https://github.com/zsh-users/zsh-syntax-highlighting"
TMUX_PLUGIN_MANAGER_GIT_REPO="https://github.com/tmux-plugins/tpm"
NVM_INSTALL_URL="https://raw.githubusercontent.com/creationix/nvm/master/install.sh"
PY_ENV_GIT_REPO="https://github.com/pyenv/pyenv.git"

# Colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
NORMAL=$(tput sgr0)
BOLD=$(tput bold)
DIM=$(tput dim)
CLEAR_LINE="\r$(tput el)"

# Output state
IS_ROLLING=0

# ============================================================================
# Color Helper Functions
# ============================================================================

function color_red() { echo -n "${RED}$*${NORMAL}"; }
function color_green() { echo -n "${GREEN}$*${NORMAL}"; }
function color_yellow() { echo -n "${YELLOW}$*${NORMAL}"; }
function color_blue() { echo -n "${BLUE}$*${NORMAL}"; }
function color_magenta() { echo -n "${MAGENTA}$*${NORMAL}"; }
function color_cyan() { echo -n "${CYAN}$*${NORMAL}"; }
function color_bold() { echo -n "${BOLD}$*${NORMAL}"; }
function color_dim() { echo -n "${DIM}$*${NORMAL}"; }

# ============================================================================
# Setup and Error Handling
# ============================================================================

# Test log file creation
if ! echo -ne "" >"$LOG_FILE" 2>/dev/null; then
  echo "Unable to create a log file in your home directory. This is a minimum requirement."
  exit 1
fi

# Death trap for nested errors
trap "exit 1" TERM
export TOP_PID=$$

function die() {
  [ $IS_ROLLING -eq 1 ] && echo
  echo
  echo "$(color_red "✗ Terminating due to an error! Check '$LOG_FILE' for details.")"

  if [ $$ -eq $TOP_PID ]; then
    exit 1
  else
    kill -s TERM $TOP_PID
  fi
}

# Logging
function log() {
  local timestamp
  timestamp=$(date '+%d/%m/%Y %H:%M:%S')
  echo "[$timestamp] $1" | sed -r "s/\\x1B\\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" >>"$LOG_FILE"
}

function log_echo() {
  log "$1"
  echo "$1"
}

function whoops() {
  [ $IS_ROLLING -eq 1 ] && echo

  log_echo "$(color_red "✗ Whoops: $1")"
  die
}

function err() {
  [ $IS_ROLLING -eq 1 ] && echo

  log_echo "$(color_red "✗ Error: $1")"
  die
}

function warn() {
  [ $IS_ROLLING -eq 1 ] && echo

  log_echo "$(color_yellow "⚠ Warning: $1")"
  IS_ROLLING=0
}

function info() {
  [ $IS_ROLLING -eq 1 ] && echo

  log_echo "$1"
  IS_ROLLING=0
}

function roll() {
  log "$1"
  echo -ne "${CLEAR_LINE}$(color_cyan "→") $1\r"
  IS_ROLLING=1
}

function success() {
  [ $IS_ROLLING -eq 1 ] && echo

  log_echo "$(color_green "✓ $1")"
  IS_ROLLING=0
}

# Run command with output redirected to log file
function run() {
  "$@" 1>>"$LOG_FILE" 2>>"$LOG_FILE"
}

# ============================================================================
# File and Directory Management
# ============================================================================

function force_dir() {
  [ -z "$1" ] && whoops "Expected one argument to function."

  local dir_name
  dir_name=$(dirname -- "$1")
  if ! run mkdir -p "$dir_name"; then
    err "Failed to create the directory '$dir_name'."
  fi
}

function link() {
  [ -z "$1" ] && whoops "Expected at least one argument to function."

  local source_path=$1
  local target_path=${2:-$1}
  local source_full="$DOTFILES_DIR/$source_path"
  local target_full="$HOME/$target_path"
  local backup_path="$BACKUP_DIR/$target_path"

  [ ! -e "$source_full" ] && whoops "The file or directory '$source_full' does not exist."

  roll "Creating a symlink from '$source_full' to '$target_full'..."

  local has_backup=0
  local should_link=1

  if [ -e "$target_full" ]; then
    roll "The file or directory '$target_full' already exists. Checking if backup necessary..."

    local current_target
    current_target=$(readlink "$target_full" || echo "$target_full")
    if [ "$current_target" != "$source_full" ]; then
      warn "Backing up '$target_full'..."
      force_dir "$backup_path"
      run rm -r -f -d "${backup_path}"

      if ! run mv "$target_full" "$backup_path"; then
        err "Failed to backup file '$target_full'."
      fi

      roll "Backed up file '$target_full' to '$backup_path'."
      has_backup=1
    else
      should_link=0
      roll "The file or directory '$target_full' points to .dotfiles. No backup will be performed."
    fi
  fi

  if [ $should_link -eq 1 ]; then
    force_dir "$target_full"

    if ! run ln -s "$source_full" "$target_full"; then
      [ $has_backup -eq 1 ] && run mv "$backup_path" "$target_full"
      err "Symlink between '$source_full' and '$target_full' failed."
    else
      roll "Symlink between '$source_full' and '$target_full' created."
    fi
  fi
}

function check_installed() {
  [ -z "$1" ] && whoops "Expected one argument to function."

  if run which "$1" || [ -f "$1" ]; then
    roll "Command '$1' has been found."
    return 0
  else
    warn "Command '$1' not found."
    return 1
  fi
}

function pull_or_clone_repo() {
  [ -z "$3" ] && whoops "Expected three arguments to function."

  local repo_name=$1
  local target_dir=$2
  local repo_url=$3

  roll "Installing $repo_name using git..."
  if [ -d "$target_dir/.git" ]; then
    roll "$repo_name is already installed. Pulling..."
    (
      cd "$target_dir" || err "Failed to change directory to '$target_dir'."
      if run git pull; then
        roll "Updated the '$repo_name' git repository to the latest version."
      else
        err "Failed to update '$repo_name' git repository."
      fi
    )
  else
    roll "Cloning '$repo_name' repository from '$repo_url'..."
    if ! run git clone "$repo_url" "$target_dir"; then
      err "Failed to clone '$repo_name' git repository."
    fi
    roll "Cloned the '$repo_name' repository into '$target_dir'."
  fi
}

function is_package_installed() {
  [ -z "$2" ] && whoops "Expected two arguments to function."
  run $1 "$2"
}

function install_packages() {
  [ -z "$2" ] && whoops "Expected two arguments to function."

  warn "Installing packages: $2"
  # shellcheck disable=SC2086
  if ! run $1 $2; then
    err "Failed to install one or more packages from the list: $2"
  fi
}

function check_and_collect_packages() {
  local check_command=$1
  shift
  local packages_to_install=""

  for package in "$@"; do
    if ! is_package_installed "$check_command" "$package"; then
      packages_to_install="${packages_to_install:+$packages_to_install }$package"
    fi
  done

  echo "$packages_to_install"
}

function check_or_install_zsh() {
  roll "Checking if the current shell is zsh..."
  local shell_name
  shell_name=$(basename -- "$SHELL")

  if [ "$shell_name" != "zsh" ]; then
    warn "The current shell ('$shell_name') is not zsh. Setting zsh as default..."
    chsh -s "$(which zsh)" || err "Failed to switch shell to zsh."
  else
    roll "Current shell is already set to zsh."
  fi
}

echo
info "$(color_blue "                              MEOW        |\__/,|   (\`\ ")"
info "$(color_blue "                                  MEOW  _.|o o  |_   ) )")"
info ".------------------------------------- $(color_blue "(((")---$(color_blue "(((")------------------------."
info "$(color_bold "| Welcome to pavkam's .dotfiles installer. Hope you enjoy the process!  |")"
info "|                                                                       |"
info "| This installer will perform the following changes:                    |"
info "|   $(color_cyan "→") Installs system dependencies (Arch/Debian/Darwin)                 |"
info "|   $(color_cyan "→") Configures zsh, oh-my-zsh and plugins (powerlevel10k, etc.)       |"
info "|   $(color_cyan "→") Sets up git configuration and global settings                     |"
info "|   $(color_cyan "→") Configures nvim with plugins                                      |"
info "|   $(color_cyan "→") Sets up tmux with plugin manager (tpm)                            |"
info "|   $(color_cyan "→") Creates symlinks for all dotfiles and configurations              |"
info "|   $(color_cyan "→") Installs development tools (Go, npm packages, pyenv, nvm)         |"
info "|   $(color_cyan "→") Configures terminal tools (kitty, bat, fzf, ripgrep, etc.)        |"
info "|   $(color_cyan "→") Sets up VS Code extensions (if installed)                         |"
info "|   $(color_cyan "→") Creates backups of existing configurations                        |"
info ":-----------------------------------------------------------------------:"
info "| $(color_yellow "⚠  WARNING: This installer comes with absolutely no guarantees!")       |"
info "| $(color_yellow "⚠  Please backup your home directory for safety reasons.")              |"
info "-------------------------------------------------------------------------"
echo

roll "Checking for basic dependencies..."

CORE_DEPENDENCIES=(sudo git)
for utility in "${CORE_DEPENDENCIES[@]}"; do
  if [ "$(which "$utility")" == "" ]; then
    err "The core utility '$utility' is not installed."
  fi
done

# Auto-update code
roll "Checking for the latest version of these .dotfiles..."
(
  cd "$DOTFILES_DIR" || err "Failed to change directory to '$DOTFILES_DIR'."

  current_branch=$(git branch --show-current)
  current_revision=$(git rev-parse HEAD)

  if [ "$current_branch" != "main" ]; then
    warn "Skipping the update of .dotfiles located at '$DOTFILES_DIR'. The current branch is not 'main'."
    exit 0
  fi

  if ! run git pull; then
    err "Failed to update the .dotfiles located at '$DOTFILES_DIR'."
  fi

  new_revision=$(git rev-parse HEAD)
  [ "$current_revision" != "$new_revision" ] && exit 2
  exit 0
)

case $? in
  2)
    warn "A new version of the .dotfiles has been pulled. Re-running the install script..."
    # shellcheck disable=SC1090
    . "$0"
    exit $?
    ;;
  1)
    exit 1
    ;;
esac

# Setup the backup directory
roll "Ensuring backup directory '$BACKUP_DIR' exists..."
if [ ! -d "$BACKUP_DIR" ]; then
  run mkdir -p "$BACKUP_DIR" || err "Failed to create the backup directory '$BACKUP_DIR'."
  roll "Created the backup directory '$BACKUP_DIR'."
else
  roll "Backup directory already exists."
fi

# Check dependencies (commands that should be installed)
roll "Checking your GNU/Linux distribution..."

DISTRO_ARCH="$(cat /etc/arch-release 2>/dev/null)"
DISTRO_DEBIAN="$(cat /etc/debian_version 2>/dev/null)"
DISTRO_DARWIN="$(uname -a | grep Darwin)"

if [ "$DISTRO_ARCH" != "" ]; then
  roll "This is an Arch-based distribution '$DISTRO_ARCH'. Checking installed packages..."

  PACKAGES=(
    yay zsh git nvim fd mc make diffutils less ripgrep sed bat util-linux nodejs npm nvm tree gcc go protobuf
    automake binutils bc bash bzip2 cmake coreutils curl cython dialog docker htop llvm lua lz4 perl pyenv
    python ruby wget zip dotnet-runtime dotnet-sdk mono bind-tools nerd-fonts-noto-sans-mono ttf-nerd-fonts-symbols-mono
    bluez-tools fzf thefuck ncdu shellcheck luarocks tmux kitty
  )

  roll "Checking which packages need to be installed..."
  packages_to_install=$(check_and_collect_packages "pacman -Q" "${PACKAGES[@]}")
  if [ "$packages_to_install" != "" ]; then
    install_packages "sudo pacman -S --noconfirm" "$packages_to_install"
    success "Packages installed successfully"
  else
    success "All packages already installed"
  fi
elif [ "$DISTRO_DEBIAN" != "" ]; then
  roll "This is a Debian-based distribution '$DISTRO_DEBIAN'. Checking installed packages..."

  PACKAGES=(
    zsh git nvim fd-find mc make diffutils less ripgrep sed bat util-linux nodejs npm tree gcc golang-go protobuf
    automake global binutils bc bash bzip2 cmake coreutils curl cython dialog docker htop llvm lua5.3 lz4
    mono-runtime perl python3 ruby wget zip bind9-utils bluez fzf apt-utils default-jre thefuck ncdu
    shellcheck luarocks tmux kitty
  )

  roll "Checking which packages need to be installed..."
  packages_to_install=$(check_and_collect_packages "dpkg -s" "${PACKAGES[@]}")
  if [ "$packages_to_install" != "" ]; then
    install_packages "apt install -y" "$packages_to_install"
    success "Packages installed successfully"
  else
    success "All packages already installed"
  fi

  # Special case over here for bat/rip on some Debian(s)
  roll "Checking if there are issues between 'ripgrep' and 'bat' due to bad packaging..."
  if ! run apt install -y ripgrep bat; then
    warn "Forcing the installation of 'ripgrep' and 'bat'..."

    if ! run sudo apt install -y -o Dpkg::Options::="--force-overwrite" bat ripgrep; then
      warn "Failed to install 'ripgrep' and 'bat' in parallel. Fix it by hand."
    fi
  fi

  roll "Checking for packages outside repositories..."

  # Check for tools not in repos - nvm
  if [ ! -e "$HOME/.nvm/nvm.sh" ] && ! command -v nvm &>/dev/null; then
    roll "Installing 'nvm'..."
    curl -s "$NVM_INSTALL_URL" | run bash || \
      warn "Failed to install nvm script. Please install by hand."
  fi

  # Check for tools not in repos - pyenv
  if [ ! -e "$HOME/.pyenv/bin/pyenv" ] && ! command -v pyenv &>/dev/null; then
    roll "Installing 'pyenv'..."
    if ! (run git clone "$PY_ENV_GIT_REPO" ~/.pyenv && \
          cd ~/.pyenv && \
          run src/configure && \
          run make -C src); then
      warn "Failed to install pyenv script. Please install by hand."
    fi
  fi
elif [ "$DISTRO_DARWIN" != "" ]; then
  roll "This is Mac. Checking installed packages using brew..."
  command -v brew &>/dev/null || err "Can only proceed if 'homebrew' is installed already."

  roll "Preparing brew ..."
  if ! run brew update || ! run brew upgrade; then
    err "Failed to prepare 'brew' for our needs."
  fi

  # Brew packages
  roll "Checking brew packages..."
  PACKAGES=(
    git nvim fd mc make diffutils less ripgrep gnu-sed bat tree gcc
    golang protobuf automake binutils bc bash bzip2 cmake global coreutils curl
    cython dialog docker htop llvm lz4 perl ruby wget zip fzf lua bind nvm pyenv
    pyenv-virtualenv node npm yarn grep jq moreutils thefuck ncdu shellcheck luarocks
    tmux buf
  )

  roll "Checking which packages need to be installed..."
  packages_to_install=$(check_and_collect_packages "brew list" "${PACKAGES[@]}")
  if [ "$packages_to_install" != "" ]; then
    install_packages "brew install" "$packages_to_install"
  else
    roll "All brew packages already installed."
  fi

  # Brew cask packages
  roll "Checking brew cask packages..."
  PACKAGES=(
    temurin font-hack-nerd-font font-symbols-only-nerd-font font-jetbrains-mono kitty
  )

  roll "Checking which cask packages need to be installed..."
  packages_to_install=$(check_and_collect_packages "brew list" "${PACKAGES[@]}")
  if [ "$packages_to_install" != "" ]; then
    install_packages "brew install --cask" "$packages_to_install"
  else
    roll "All brew cask packages already installed."
  fi
else
  warn "This GNU/Linux distribution is not supported. Install the dependencies by hand."
fi

# Optional dependencies
if command -v npm &>/dev/null; then
  roll "Installing npm packages ..."

  if ! run npm install -g editorconfig; then
    whoops "Failed to install npm packages."
  fi
fi

# Check all required dependencies are installed
CORE_DEPENDENCIES_CHECK=(git nvim zsh fzf mc gcc java diff make less sed head chsh go node npm tree ln readlink)
ARCH_DEPENDENCIES=(fd "$HOME/.nvm/nvm.sh" rg bat pyenv)
DEBIAN_DEPENDENCIES=(fdfind "$HOME/.nvm/nvm.sh" rg batcat "$HOME/.pyenv/bin/pyenv")
DARWIN_DEPENDENCIES=(fd "/opt/homebrew/opt/nvm/nvm.sh" rg bat pyenv)

if [ "$DISTRO_ARCH" != "" ]; then
  DEPENDENCIES=("${CORE_DEPENDENCIES_CHECK[@]}" "${ARCH_DEPENDENCIES[@]}")
elif [ "$DISTRO_DEBIAN" != "" ]; then
  DEPENDENCIES=("${CORE_DEPENDENCIES_CHECK[@]}" "${DEBIAN_DEPENDENCIES[@]}")
elif [ "$DISTRO_DARWIN" != "" ]; then
  DEPENDENCIES=("${CORE_DEPENDENCIES_CHECK[@]}" "${DARWIN_DEPENDENCIES[@]}")
else
  DEPENDENCIES=("${CORE_DEPENDENCIES_CHECK[@]}")
fi

has_missing_dependencies=0
for dependency in "${DEPENDENCIES[@]}"; do
  if ! check_installed "$dependency"; then
    has_missing_dependencies=1
  fi
done

if [ $has_missing_dependencies -eq 1 ]; then
  err "Please install the missing dependencies before continuing the installation!"
else
  roll "All dependencies are installed."
fi

# Setup the shell & Oh-My-Zsh
check_or_install_zsh

oh_my_zsh_dir=${ZSH:-$HOME/.oh-my-zsh}
pull_or_clone_repo "Oh-My-Zsh" "$oh_my_zsh_dir" "$OH_MY_ZSH_GIT_REPO"

power_level_10k_dir=${ZSH_CUSTOM:-$oh_my_zsh_dir/custom}/themes/powerlevel10k
pull_or_clone_repo "Power-level 10K" "$power_level_10k_dir" "$POWER_LEVEL_10K_GIT_REPO"

zsh_autosuggestions_dir=${ZSH_CUSTOM:-$oh_my_zsh_dir/custom}/plugins/zsh-autosuggestions
pull_or_clone_repo "Zsh Auto-Suggestions" "$zsh_autosuggestions_dir" "$ZSH_AUTO_SUGGESTIONS_GIT_REPO"

zsh_history_substring_dir=${ZSH_CUSTOM:-$oh_my_zsh_dir/custom}/plugins/zsh-history-substring-search
pull_or_clone_repo "Zsh History Substring Search" "$zsh_history_substring_dir" "$ZSH_HISTORY_SUBSTRING_GIT_REPO"

zsh_syntax_highlighting_dir=${ZSH_CUSTOM:-$oh_my_zsh_dir/custom}/plugins/zsh-syntax-highlighting
pull_or_clone_repo "Zsh Syntax Highlighting" "$zsh_syntax_highlighting_dir" "$ZSH_SYNTAX_HIGHLIGHTING_GIT_REPO"

# Create all the symlinks
roll "Creating all symlinks..."

link .dir_colors
link .gitconfig
link .gitignore.global
link .gitattributes.global
link .editorconfig
link Pipfile
link .zshrc
link .zshenv
link .zprofile
link .zshrc.p10k
link .curlrc
link .wgetrc
link .nuget/NuGet/NuGet.Config
link .config/mc
link .config/htop
link .config/kitty
link .config/bat
link .config/yazi
link .docker/config.json
link .docker/daemon.json
link .docker/features.json

if [ "$DISTRO_DARWIN" = "" ]; then
  link .config/Code/User/settings.json
  link .config/Code/User/keybindings.json
  link .config/lazygit/config.yml
else
  link .config/Code/User/settings.json "./Library/Application Support/Code/User/settings.json"
  link .config/Code/User/keybindings.json "./Library/Application Support/Code/User/keybindings.json"
  link .config/Cursor/User/settings.json "./Library/Application Support/Cursor/User/settings.json"
  link .config/Cursor/User/keybindings.json "./Library/Application Support/Cursor/User/keybindings.json"
  link .terminfo
  link "./Library/KeyBindings/DefaultKeyBinding.dict"
  link "./Library/LaunchAgents/com.local.KeyRemapping.plist"
  link .config/lazygit/config.yml "./Library/Application Support/lazygit/config.yml"
fi

link .aws/cli/alias

roll "Setting up NeoVim..."
link .config/nvim
roll "NeoVim ready to use..."

# Setup tmux
roll "Setting up Tmux..."
pull_or_clone_repo "Tmux Plugin Manager" "$HOME/.tmux/plugins/tpm" "$TMUX_PLUGIN_MANAGER_GIT_REPO"

roll "Tmux is installed and at the latest version."
link .config/tmux/tmux.conf

roll "Tmux ready to use!"

roll "Setting up bat..."
if ! run bat cache --build; then
  warn "Failed to build bat cache. Please run 'bat cache --build' by hand."
fi
roll "Bat ready to use!"

if check_installed "code"; then
  roll "Installing VS Code extensions..."
  if ! cat <"$DOTFILES_DIR"/vs-extensions.txt | xargs -L 1 run code --install-extension; then
    err "Failed install VS Code extensions."
  fi

  roll "Finished installing VS Code extensions."
else
  warn "VS Code not installed. Skipping extension installation."
fi

# Prepare go stuff, if installed
if command -v go &>/dev/null; then
  roll "Installing go packages..."
  export GOPATH="$HOME/.go"

  GO_PACKAGES=(
    "github.com/pressly/goose/v3/cmd/goose@latest"
    "github.com/incu6us/goimports-reviser/v3@latest"
    "github.com/golang/protobuf/protoc-gen-go@latest"
    "google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest"
    "gotest.tools/gotestsum@latest"
    "github.com/segmentio/golines@latest"
    "github.com/go-delve/delve/cmd/dlv@latest"
  )

  for go_package in "${GO_PACKAGES[@]}"; do
    roll "Installing go package: $go_package ..."
    if ! run go install -v "$go_package"; then
      err "Failed to install go package: $go_package"
    fi
  done

  roll "Finished installing go packages..."
fi

# Create local configuration files if they don't exist
for config_file in .zshrc.local .zshenv.local; do
  local_config_file="$HOME/$config_file"
  if [ ! -f "$local_config_file" ]; then
    config_name="${config_file%.local}"
    echo "# Place all your personalized '$config_name' commands in this file." >"$local_config_file"
    roll "Created $local_config_file file to hold personalized commands."
  fi
done

echo
info "$(color_blue "                                   |\      _,,,---,,_         ")"
info "$(color_blue "                              ZZZzz /,\`.-'\`'    -.  ;-;;,_  ")"
info "$(color_blue "                                   |,4-  ) )-,_. ,\ (  \`'-'  ")"
info "$(color_blue "                                  '---''(_/--'  \`-'\_)       ")"

echo
success "All done! You're good to go!"

echo
