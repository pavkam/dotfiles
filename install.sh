#!/bin/bash
# ---------------------------------------------------------------------------
# | pavkam's .dotfiles installation script.                                 |
# |                                                                         |
# | No warranties are provided, no responsibility is taken. You're on your  |
# | own! I will recommend you backup your home before trying this script.   |
# ---------------------------------------------------------------------------

# Logging.
LOG_FILE=~/.dotfiles.log
if ! echo -ne "" >~/.dotfiles.log 2>/dev/null; then
  echo "Unable to create a log file in your home directory. This is a minimum requirement."
  exit 1
fi

# Colors .
RED=$(tput setaf 1)
BROWN=$(tput setaf 3)
NORMAL=$(tput sgr0)
BLUE=$(tput setaf 4)
CLEARRET="\r$(tput el)"
ROLLING=0

# Death
trap "exit 1" TERM
export TOP_PID=$$

DFN=$(realpath "$0")
DF=$(dirname "$DFN")

function die() {
  echo
  echo "${RED}Terminating due to an error! Check '$LOG_FILE' for details."

  if [ $$ -eq $TOP_PID ]; then
    exit 1
  else
    kill -s TERM $TOP_PID
  fi
}

# Logging
function log() {
  TIME=$(date '+%d/%m/%Y %H:%M:%S')
  echo "[$TIME] $1" | sed -r "s/\\x1B\\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" >>$LOG_FILE
}

function log_echo() {
  log "$1"
  echo "$1"
}

function whoops() {
  if [ $ROLLING -eq 1 ]; then
    echo
  fi

  log_echo "${RED}Whoops: $1"
  die
}

function err() {
  if [ $ROLLING -eq 1 ]; then
    echo
  fi

  log_echo "${RED}Error: $1"
  die
}

function warn() {
  if [ $ROLLING -eq 1 ]; then
    echo
  fi

  log_echo "${BROWN}Warning: $1"
  ROLLING=0
}

function info() {
  if [ $ROLLING -eq 1 ]; then
    echo
  fi

  log_echo "${NORMAL}$1"
  ROLLING=0
}

function roll() {
  log "$1"
  echo -ne "${CLEARRET}${NORMAL}$1"
  ROLLING=1
}

# Deal with backups.

BACKUP=$HOME/.dotfiles.backup

function force_dir() {
  if [ "$1" = "" ]; then
    whoops "Expected one argument to function."
  fi

  DN=$(dirname -- "$1")

  if ! mkdir -p "$DN" 1>>$LOG_FILE 2>>$LOG_FILE; then
    err "Failed to create the directory '$DN'."
  fi
}

function link() {
  FROM=$1
  TO=$2
  if [ "$FROM" = "" ]; then
    whoops "Expected at least one  argument to function."
  fi

  if [ "$TO" == "" ]; then
    TO=$FROM
  fi

  if [ ! -e "$DF/$FROM" ]; then
    whoops "The file or directory '$DF/$FROM' does not exist."
  fi

  roll "Creating a symlink from '$DF/$FROM' to '$HOME/$TO'..."

  HAS_BACKUP=0
  DO_LN=1
  if [ -e "$HOME/$TO" ]; then
    roll "The file or directory '$HOME/$TO' already exists. Checking if backup necessary..."

    CHECK_DEST=$(readlink "$HOME/$TO" || echo "$HOME/$TO")
    if [ "$CHECK_DEST" != "$DF/$FROM" ]; then
      warn "Backing up '$HOME/$TO'..."

      force_dir "$BACKUP/$TO"

      rm -r -f -d "${BACKUP:?}/${TO}" 1>>$LOG_FILE 2>>$LOG_FILE
      if ! mv "$HOME/$TO" "$BACKUP/$TO" 1>>$LOG_FILE 2>>$LOG_FILE; then
        err "Failed to backup file '$HOME/$TO'."
      fi

      roll "Backed up file '$HOME/$TO' to '$BACKUP/$TO'."
      HAS_BACKUP=1
    else
      DO_LN=0
      roll "The file or directory '$HOME/$TO' points to .dotfiles. No backup will be performed."
    fi
  fi

  if [ $DO_LN -eq 1 ]; then
    force_dir "$HOME/$TO"

    if ! ln -s "$DF/$FROM" "$HOME/$TO" 1>>$LOG_FILE 2>>$LOG_FILE; then
      if [ $HAS_BACKUP -eq 1 ]; then

        if ! mv "$BACKUP/$TO" "$HOME/$TO" 1>>$LOG_FILE 2>>$LOG_FILE; then
          warn "Failed to restore file '$HOME/$TO' from its backup."
        fi
      fi

      err "Symlink between '$DF/$FROM' and '$HOME/$TO' failed."
    else
      roll "Symlink between '$DF/$FROM' and '$HOME/$TO' created."
    fi
  fi
}

function check_installed() {
  if [ "$1" = "" ]; then
    whoops "Expected one argument to function."
  fi

  if ! which "$1" 1>>$LOG_FILE 2>>$LOG_FILE && [ ! -f "$1" ]; then
    warn "Command '$1' not found."
    return 1
  else
    roll "Command '$1' has been found."
    return 0
  fi
}

function pull_or_clone_repo() {
  if [ "$1" = "" ] || [ "$2" = "" ] || [ "$3" = "" ]; then
    whoops "Expected three arguments to function."
  fi

  NAME=$1
  DIR=$2
  URL=$3

  roll "Installing $NAME using git..."
  if [ -d "$DIR/.git" ]; then
    roll "$NAME is already installed. Pulling..."
    (
      if ! cd "$DIR"; then
        err "Failed to change directory to '$DIR'."
      fi

      if ! git pull 1>>$LOG_FILE 2>>$LOG_FILE; then
        err "Failed to update '$NAME' git repository."
      else
        roll "Updated the '$NAME' git repository to the latest version."
      fi
    )
  else
    roll "Cloning '$NAME' repository from '$URL'..."

    if ! git clone "$URL" "$DIR" 1>>$LOG_FILE 2>>$LOG_FILE; then
      err "Failed to clone '$NAME' git repository."
    fi

    roll "Cloned the '$NAME' repository into '$DIR'."
  fi
}

function is_package_installed() {
  if [ "$2" = "" ]; then
    whoops "Expected two arguments to function."
  fi

  roll "Checking if package '$2' is installed..."
  if ! $1 "$2" 1>>$LOG_FILE 2>>$LOG_FILE; then
    roll "Package '$2' not installed."
    return 1
  else
    roll "Package '$2' is already installed."
    return 0
  fi
}

function install_packages() {
  if [ "$2" = "" ]; then
    whoops "Expected two arguments to function."
  fi

  warn "Installing packages ['$2']..."

  if ! $1 "$2" 1>>$LOG_FILE 2>>$LOG_FILE; then
    err "Failed to install one or more packages from the list ['$2']."
  fi
}

function check_or_install_zsh() {
  roll "Checking if the the current shell is zsh..."
  SHELL_NAME=$(basename -- "$SHELL")
  if [ "$SHELL_NAME" != "zsh" ]; then
    warn "The current shell ('$SHELL_NAME') is not zsh. Setting zsh as default..."
    if ! chsh -s "$(which zsh)"; then
      err "Failed to switch shell to zsh."
    fi
  else
    roll "Nothing to do, current shell is already set to zsh."
  fi
}

info "${BLUE}                              MEOW        |\__/,|   (\`\                "
info "${BLUE}                                  MEOW  _.|o o  |_   ) )                "
info ".-------------------------------------- ${BLUE}(((${NORMAL}---${BLUE}(((${NORMAL}-----------------------."
info "| Welcome to pavkam's .dotfiles installer. Hope you enjoy the process! |"
info "| This installer will perform the following changes:                   |"
info "|     *   Installs dependencies (Arch/Debian/Darwin),                  |"
info "|     *   Configures zsh, oh-my-zsh and plugins,                       |"
info "|     *   Configures git and its settings,                             |"
info "|     *   Configures nvim, and its plugins.                            |"
info ":----------------------------------------------------------------------:"
info "| ${RED}WARNING: This installer comes with absolutely no guarantees!${NORMAL}         |"
info "| ${RED}Please backup your home directory for safety reasons.${NORMAL}                |"
info "------------------------------------------------------------------------"
info ""

roll "Checking for basic dependencies..."

CORE_DEPS=(sudo git)
for i in "${CORE_DEPS[@]}"; do
  if [ "$(which "$i")" == "" ]; then
    err "The core utility '$i' is not installed."
  fi
done

# Auto-update code
roll "Checking for the latest version of these .dotfiles..."
(
  if ! cd "$DF"; then
    err "Failed to change directory to '$DF'."
  fi

  CURB=$(git branch --show-current)
  CREV=$(git rev-parse HEAD)

  if [ "$CURB" != "main" ]; then
    warn "Skipping the update of .dotfiles located at '$DF'. The current branch is not 'master'."
  else

    if ! git pull 1>>$LOG_FILE 2>>$LOG_FILE; then
      err "Failed to update the .dotfiles located at '$DF'."
      exit 1
    else
      VREV=$(git rev-parse HEAD)
      if [ "$CREV" != "$VREV" ]; then
        exit 2
      fi
    fi
  fi

  exit 0
)

PULL_CODE=$?
if [ $PULL_CODE -eq 2 ]; then
  warn "A new version of the .dotfiles has been pulled. Re-running the install script..."
  # shellcheck disable=SC1090
  . "$0"
  exit $?
elif [ $PULL_CODE -eq 1 ]; then
  exit 1
fi

# Setup the backup
roll "Checking if the backup directory '$BACKUP' already exists..."
if [ ! -d "$BACKUP" ]; then
  roll "The backup directory '$BACKUP' does not exist. Creating..."

  if ! mkdir -p "$BACKUP" 1>>$LOG_FILE 2>>$LOG_FILE; then
    err "Failed to create the backup directory '$BACKUP'."
  fi

  roll "Created the backup directory '$BACKUP'."
else
  roll "The backup directory '$BACKUP' already exists."
fi

# Check dependencies (commands that should be installed)
roll "Checking your GNU/Linux distribution..."

DISTRO_ARCH="$(cat /etc/arch-release 2>/dev/null)"
DISTRO_DEBIAN="$(cat /etc/debian_version 2>/dev/null)"
DISTRO_DARWIN="$(uname -a | grep Darwin)"

if [ "$DISTRO_ARCH" != "" ]; then
  roll "This is an Arch-based distribution '$DISTRO_ARCH'. Checking installed packages..."

  PACKS=(
    yay zsh git nvim fd mc make diffutils less ripgrep sed bat util-linux nodejs npm nvm tree gcc go protobuf
    automake binutils bc bash bzip2 cmake coreutils curl cython dialog docker htop llvm lua lz4 perl pyenv
    python ruby wget zip dotnet-runtime dotnet-sdk mono bind-tools nerd-fonts-noto-sans-mono ttf-nerd-fonts-symbols-mono
    bluez-tools fzf thefuck ncdu shellcheck luarocks tmux kitty
  )

  TO_INSTALL=""
  for i in "${PACKS[@]}"; do
    if is_package_installed "pacman -Q" "$i"; then
      TO_INSTALL="$TO_INSTALL $i"
    fi
  done

  if [ "$TO_INSTALL" != "" ]; then
    install_packages "sudo pacman -S --noconfirm" "$TO_INSTALL"
  fi
elif [ "$DISTRO_DEBIAN" != "" ]; then
  roll "This is a Debian-based distribution '$DISTRO_DEBIAN'. Checking installed packages..."

  PACKS=(
    zsh git nvim fd-find mc make diffutils less ripgrep sed bat util-linux nodejs npm tree gcc golang-go protobuf
    automake global binutils bc bash bzip2 cmake coreutils curl cython dialog docker htop llvm lua5.3 lz4
    mono-runtime perl python3 ruby wget zip bind9-utils bluez fzf apt-utils default-jre thefuck ncdu
    shellcheck luarocks tmux kitty
  )

  TO_INSTALL=""
  for i in "${PACKS[@]}"; do
    if is_package_installed "dpkg -s" "$i"; then
      TO_INSTALL="$TO_INSTALL $i"
    fi
  done

  if [ "$TO_INSTALL" != "" ]; then
    install_packages "apt install -y" "$TO_INSTALL"
  fi

  # Special case over here for bat/rip on some Debians
  roll "Checking if there are issues between 'ripgrep' and 'bat' due to bad packaging..."
  apt install -y ripgrep bat 1>>$LOG_FILE 2>>$LOG_FILE
  if ! apt install -y ripgrep bat 1>>$LOG_FILE 2>>$LOG_FILE; then
    warn "Forcing the installation of 'ripgrep' and 'bat'..."

    if ! sudo apt install -y -o Dpkg::Options::="--force-overwrite" bat ripgrep 1>>$LOG_FILE 2>>$LOG_FILE; then
      warn "Failed to install 'ripgrep' and 'bat' in parallel. Fix it by hand."
    fi
  fi

  roll "Checking for packages outside repositories..."

  # Check for tools not in repos - nvm.
  if [ ! -e "$HOME/.nvm/nvm.sh" ] && [ "$(which nvm)" == "" ]; then
    roll "Installing 'nvm'..."
    if ! curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash 1>>$LOG_FILE 2>>$LOG_FILE; then
      warn "Failed to install nvm script. Please install by hand."
    fi
  fi

  # Check for tools not in repos - pyenv.
  if [ ! -e "$HOME/.pyenv/bin/pyenv" ] && [ "$(which pyenv)" == "" ]; then
    roll "Installing 'pyenv'..."
    (
      git clone https://github.com/pyenv/pyenv.git ~/.pyenv 1>>$LOG_FILE 2>>$LOG_FILE || exit 1
      cd ~/.pyenv || exit 1
      src/configure 1>>$LOG_FILE 2>>$LOG_FILE || exit 1
      make -C src 1>>$LOG_FILE 2>>$LOG_FILE || exit 1
    )

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
      warn "Failed to install pyenv script. Please install by hand."
    fi
  fi
elif [ "$DISTRO_DARWIN" != "" ]; then
  roll "This is Mac. Checking installed packages using brew..."
  if ! command -v brew &>/dev/null; then
    err "Can only proceed if 'homebrew' is installed already."
    die
  fi

  roll "Preparing brew ..."
  (
    brew update 1>>$LOG_FILE 2>>$LOG_FILE || exit 1
    brew upgrade 1>>$LOG_FILE 2>>$LOG_FILE || exit 1
  )

  # shellcheck disable=SC2181
  if [ $? -ne 0 ]; then
    err "Failed to prepare 'brew' for our needs."
    die
  fi

  # Brew packages
  roll "Installing brew packages ..."
  PACKS=(
    git nvim fd mc make diffutils less ripgrep gnu-sed bat tree gcc
    golang protobuf automake binutils bc bash bzip2 cmake global coreutils curl
    cython dialog docker htop llvm lz4 perl ruby wget zip fzf lua bind nvm pyenv
    pyenv-virtualenv node npm yarn grep jq moreutils thefuck ncdu shellcheck luarocks
    tmux buf
  )

  TO_INSTALL=""
  for i in "${PACKS[@]}"; do

    if ! is_package_installed "brew list" "$i"; then
      TO_INSTALL="$TO_INSTALL $i"
    fi
  done

  if [ "$TO_INSTALL" != "" ]; then
    install_packages "brew install" "$TO_INSTALL"
  fi

  # Brew cask packages
  roll "Installing brew cask packages ..."
  PACKS=(
    temurin font-hack-nerd-font font-symbols-only-nerd-font font-jetbrains-mono kitty
  )

  TO_INSTALL=""
  for i in "${PACKS[@]}"; do
    if is_package_installed "brew list" "$i"; then
      TO_INSTALL="$TO_INSTALL $i"
    fi
  done

  if [ "$TO_INSTALL" != "" ]; then
    install_packages "brew install --cask" "$TO_INSTALL"
  fi
else
  warn "This GNU/Linux distribution is not supported. Install the dependencies by hand."
fi

# Optional dependencies
if command -v npm 1>$LOG_FILE 2>&1; then
  roll "Installing npm packages ..."

  if ! npm install -g editorconfig 1>>$LOG_FILE 2>>$LOG_FILE; then
    whoops "Failed to install npm packages."
  fi
fi

# ...

CORE_DEPS=(git nvim zsh fzf mc gcc java diff make less sed head chsh go node npm tree ln readlink)
ARCH_DEPS=(fd "$HOME/.nvm/nvm.sh" rg bat pyenv)
DEBIAN_DEPS=(fdfind "$HOME/.nvm/nvm.sh" rg batcat "$HOME/.pyenv/bin/pyenv")
DARWIN_DEPS=(fd "/opt/homebrew/opt/nvm/nvm.sh" rg bat pyenv)

if [ "$DISTRO_ARCH" != "" ]; then
  DEPS=("${CORE_DEPS[@]}" "${ARCH_DEPS[@]}")
elif [ "$DISTRO_DEBIAN" != "" ]; then
  DEPS=("${CORE_DEPS[@]}" "${DEBIAN_DEPS[@]}")
elif [ "$DISTRO_DARWIN" != "" ]; then
  DEPS=("${CORE_DEPS[@]}" "${DARWIN_DEPS[@]}")
else
  DEPS=("${CORE_DEPS[@]}")
fi

MUST_DIE=0
for i in "${DEPS[@]}"; do
  if ! check_installed "$i"; then
    MUST_DIE=1
  fi
done

if [ $MUST_DIE -eq 1 ]; then
  err "Please install the missing dependencies before continuing the installation!"
  die
else
  roll "All dependencies are installed."
fi

# Setup the shell & Oh-My-Zsh
check_or_install_zsh

OHMYZSH_DIR=${ZSH:-$HOME/.oh-my-zsh}
pull_or_clone_repo "Oh-My-Zsh" "$OHMYZSH_DIR" "https://github.com/ohmyzsh/ohmyzsh.git"

POWERLEVEL_10K_DIR=${ZSH_CUSTOM:-$OHMYZSH_DIR/custom}/themes/powerlevel10k
pull_or_clone_repo "Power-level 10K" "$POWERLEVEL_10K_DIR" "https://github.com/romkatv/powerlevel10k.git"

ZSH_AUTOSUGGESTIONS_DIR=${ZSH_CUSTOM:-$OHMYZSH_DIR/custom}/plugins/zsh-autosuggestions
pull_or_clone_repo "Zsh Auto-Suggestions" "$ZSH_AUTOSUGGESTIONS_DIR" "https://github.com/zsh-users/zsh-autosuggestions"

ZSH_HISTORY_SUBSTRING_SEARCH_DIR=${ZSH_CUSTOM:-$OHMYZSH_DIR/custom}/plugins/zsh-history-substring-search
pull_or_clone_repo "Zsh History Substring Search" "$ZSH_HISTORY_SUBSTRING_SEARCH_DIR" "https://github.com/zsh-users/zsh-history-substring-search"

ZSH_SYNTAX_HIGHLIGHTING_DIR=${ZSH_CUSTOM:-$OHMYZSH_DIR/custom}/plugins/zsh-syntax-highlighting
pull_or_clone_repo "Zsh Syntax Highlighting" "$ZSH_SYNTAX_HIGHLIGHTING_DIR" "https://github.com/zsh-users/zsh-syntax-highlighting"

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
pull_or_clone_repo "Tmux" "$HOME/.tmux/plugins/tpm" "https://github.com/tmux-plugins/tpm"

roll "Tmux is installed and at the latest version."
link .config/tmux/tmux.conf

roll "Tmux ready to use!"

roll "Setting up bat..."
if ! bat cache --build 1>>$LOG_FILE 2>>$LOG_FILE; then
  warn "Failed to build bat cache. Please run 'bat cache --build' by hand."
fi
roll "Bat ready to use!"

if ! check_installed "code"; then
  roll "Installing VS Code extensions..."
  if cat <"$DF"/vs-extensions.txt | xargs -L 1 code --install-extension 1>>$LOG_FILE 2>>$LOG_FILE; then
    err "Failed install VS Code extensions."
  fi

  roll "Finished installing VS Code extensions."
else
  warn "VS Code not installed. Skipping extension installation."
fi

# Prepare go stuff, if installed
if command -v go 1>$LOG_FILE 2>&1; then
  roll "Installing go packages..."
  export GOPATH="$HOME/.go"

  GO_PACKS=(
    "github.com/pressly/goose/v3/cmd/goose@latest"
    "github.com/incu6us/goimports-reviser/v3@latest"
    "github.com/golang/protobuf/protoc-gen-go@latest"
    "google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest"
    "gotest.tools/gotestsum@latest"
    "github.com/segmentio/golines@latest"
    "github.com/go-delve/delve/cmd/dlv@latest"
  )

  for i in "${GO_PACKS[@]}"; do
    roll "Installing go package: $i ..."
    if ! go install -v "$i" 1>>$LOG_FILE 2>>$LOG_FILE; then
      err "Failed to install go package: $i"
    fi
  done

  roll "Finished installing go packages..."
fi

LOCALF="$HOME/.zshrc.local"
if [ ! -f "$LOCALF" ]; then
  echo "# Place all your personalized '.zshrc' commands in this file." >"$LOCALF"
  roll "Created the $LOCALF file to hold personalized commands."
fi

LOCALF="$HOME/.zshenv.local"
if [ ! -f "$LOCALF" ]; then
  echo "# Place all your personalized '.zshenv' commands in this file." >"$LOCALF"
  roll "Created the $LOCALF file to hold personalized commands."
fi

info
info "${BLUE}                                   |\      _,,,---,,_        "
info "${BLUE}                              ZZZzz /,\`.-'\`'    -.  ;-;;,_  "
info "${BLUE}                                   |,4-  ) )-,_. ,\ (  \`'-'  "
info "${BLUE}                                  '---''(_/--'  \`-'\_)       "
info
info "All done! You're good to go!"
