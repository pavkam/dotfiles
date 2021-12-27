#!/bin/bash
# ---------------------------------------------------------------------------
# | pavkam's .dotfiles installation script.                                 |
# |                                                                         |
# | No warranties are provided, no responsability is taken. You're on your  |
# | own! I will recommend you backup your home before trying this script.   |
# ---------------------------------------------------------------------------

# Logging.
LOG_FILE=~/.dotfiles.log
echo -ne "" > ~/.dotfiles.log 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Unable to create a log file in your home directory. This is a minimum requirement."
    exit 1
fi

# Colors .
RED=`tput setaf 1`
BROWN=`tput setaf 3`
NORMAL=`tput sgr0`
BLUE=`tput setaf 4`
CLEARRET="\r`tput el`"
ROLLING=0

# Death
trap "exit 1" TERM
export TOP_PID=$$

DFN=`realpath $0`
DF=`dirname $DFN`

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
    TIME=`date '+%d/%m/%Y %H:%M:%S'`
    echo "[$TIME] $1" | sed -r "s/\\x1B\\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" >> $LOG_FILE
}

function log_echo() {
    log "$1"
    echo "$1"
}


function whoops() {
    if [ $ROLLING -eq 1 ]; then
        echo
    fi

    log_echo "$RED      Whoops: $1"
    die
}

function err() {
    if [ $ROLLING -eq 1 ]; then
        echo
    fi

    log_echo "$RED      Error: $1"
    die
}

function warn() {
    if [ $ROLLING -eq 1 ]; then
        echo
    fi

    log_echo "$BROWN    Warning: $1"
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

    DN=`dirname -- "$1"`
    mkdir -p "$DN" &>> $LOG_FILE
    if [ $? -ne 0 ]; then
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

        CHECK_DEST=`readlink -f "$HOME/$TO"`
        if [ "$CHECK_DEST" != "$DF/$FROM" ]; then
            warn "Backing up '$HOME/$TO'..."

            force_dir "$BACKUP/$TO"

            rm -r -f -d "$BACKUP/$TO" &>> $LOG_FILE
			mv "$HOME/$TO" "$BACKUP/$TO" &>> $LOG_FILE
            if [ $? -ne 0 ]; then
                err "Failed to backup file '$HOME/$TO'."
            fi

            roll "Backed up file '$HOME/$TO' to '$BACKUP/$TO'."
            HAS_BACKUP=1
        else
            DO_LN=0
            roll "The file of directory '$HOME/$TO' points to .dotfiles. No backup will be performed."
        fi
    fi

    if [ $DO_LN -eq 1 ]; then
        force_dir "$HOME/$TO"
        ln -s "$DF/$FROM" "$HOME/$TO" &>> $LOG_FILE

        if [ $? -ne 0 ]; then
            if [ $HAS_BACKUP -eq 1 ]; then
                mv "$BACKUP/$TO" "$HOME/$TO" &>> $LOG_FILE
                if [ $? -ne 0 ]; then
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

    which "$1" &>> $LOG_FILE
    if [ $? -ne 0 ] && [ ! -f "$1" ]; then
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
    if [ -d "$DIR" ]; then
        roll "$NAME is already installed. Pulling..."
        (
            cd "$DIR"
            git pull &>> $LOG_FILE
            if [ $? -ne 0 ]; then
                err "Failed to update '$NAME' git repository."
            else
                roll "Updated the '$NAME' git repository to the latest version."
            fi
    )
    else
        roll "Cloning '$NAME' repository from '$URL'..."
        git clone "$URL" "$DIR" &>> $LOG_FILE
        if [ $? -ne 0 ]; then
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
    $1 "$2" &>> $LOG_FILE
    if [ $? -ne 0 ]; then
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
    $1 $2 &>> $LOG_FILE
    if [ $? -ne 0 ]; then
        err "Failed to install one or more packages from the list ['$2']."
    fi
}

function check_or_install_zsh() {
    roll "Checking if the the current shell is zsh..."
    SHELL_NAME=`basename -- $SHELL`
    if [ "$SHELL_NAME" != "zsh" ]; then
        warn "The current shell ('$SHELL_NAME') is not zsh. Setting zsh as default..."
        chsh -s $(which zsh)
        if [ $? -ne 0 ]; then
            err "Failed to switch shell to zsh."
        fi
    else
        roll "Nothing to do, current shell is already set to zsh."
    fi
}

info "${BLUE}                              MEOW        |\__/,|   (\`\                "
info "${BLUE}                                  MEOW  _.|o o  |_   ) )                "
info ".--------------------------------------${BLUE}(((${NORMAL}---${BLUE}(((${NORMAL}-----------------------."
info "| Welcome to pavkam's .dotfiles installer. Hope you enjoy the proces!  |"
info "| This installer will perform the following changes:                   |"
info "|     *   Installs dependencies (on Arch-based distros),               |"
info "|     *   Configures zsh, oh-my-zsh and plugins,                       |"
info "|     *   Configures git and its settings,                             |"
info "|     *   Configures vim, Vundle and plugins.                          |"
info ":----------------------------------------------------------------------:"
info "| ${RED}WARNING: This installer comes with absolutely no guarantees!${NORMAL}         |"
info "| ${RED}Please backup your home directory for safety reasons.${NORMAL}                |"
info "------------------------------------------------------------------------"
info

roll "Checking for basic dependencies..."

CORE_DEPS=( sudo git )
for i in "${CORE_DEPS[@]}"
do
    if [ "`which $i`" == "" ]; then
        err "The core utility '$i' is not installed."
    fi
done

# Auto-update code
roll "Checking for the latest version of these .dotfiles..."
(
    cd "$DF"
    CURB=`git branch --show-current`
    CREV=`git rev-parse HEAD`

    if [ "$CURB" != "main" ]; then
        warn "Skipping the update of .dotfiles located at '$DF'. The current branch is not 'master'."
    else
        git pull &>> $LOG_FILE
        if [ $? -ne 0 ]; then
            err "Failed to update the .dotfiles located at '$DF'."
            exit 1
        else
            VREV=`git rev-parse HEAD`
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
    . $0
    exit $?
elif [ $PULL_CODE -eq 1 ]; then
    exit 1
fi

# Setup the backup
roll "Checking if the backup directory '$BACKUP' already exists..."
if [ ! -d "$BACKUP" ]; then
    roll "The backup directory '$BACKUP' does not exist. Creating..."
    mkdir -p "$BACKUP" &>> $LOG_FILE
    if [ $? -ne 0 ]; then
        err "Failed to create the backup directory '$BACKUP'."
    fi

    roll "Created the backup directory '$BACKUP'."
else
    roll "The backup directory '$BACKUP' already exists."
fi

# Check dependencies (commands that should be installed)
roll "Checking your GNU/Linux distribution..."

DISTRO_ARCH="`cat /etc/arch-release 2>/dev/null`"
DISTRO_DEBIAN="`cat /etc/debian_version 2>/dev/null`"

if [ "$DISTRO_ARCH" != "" ]; then
    roll "This is an Arch-based ditribution '$DISTRO_ARCH'. Checking installed packages..."

    PACKS=(
        yay zsh vim git fd mc make diffutils less ripgrep sed bat util-linux nodejs npm nvm tree gcc go automake binutils bc
        bash bzip2 cmake coreutils curl cython dialog docker htop llvm lua lz4 perl pyenv python python2 ruby wget
        zip dotnet-runtime dotnet-sdk mono bind-tools nerd-fonts-noto-sans-mono bluez-tools
    )

    TO_INSTALL=""
    for i in "${PACKS[@]}"
    do
        is_package_installed "pacman -Q" $i
        if [ $? -ne 0 ]; then
            TO_INSTALL="$TO_INSTALL $i"
        fi
    done

    if [ "$TO_INSTALL" != "" ]; then
        install_packages "sudo pacman -S --noconfirm" "$TO_INSTALL"
    fi
elif [ "$DISTRO_DEBIAN" != "" ]; then
    roll "This is a Debian-based ditribution '$DISTRO_DEBIAN'. Checking installed packages..."

    # curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
    # git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    # cd ~/.pyenv && src/configure && make -C src
    # dotnet-runtime dotnet-sdk
    # nerd-fonts-noto-sans-mono

    PACKS=(
        zsh vim git fd-find mc make diffutils less ripgrep sed bat util-linux nodejs npm tree gcc golang-go automake binutils bc
        bash bzip2 cmake coreutils curl cython dialog docker htop llvm lua5.3 lz4 mono-runtime perl python python2 ruby wget
        zip bind9-utils bluez
    )

    TO_INSTALL=""
    for i in "${PACKS[@]}"
    do
        is_package_installed "dpkg -s" $i
        if [ $? -ne 0 ]; then
            TO_INSTALL="$TO_INSTALL $i"
        fi
    done

    if [ "$TO_INSTALL" != "" ]; then
        install_packages "apt install -y" "$TO_INSTALL"
    fi

else
    warn "This GNU/Linux distribution is not supported. Install the dependancies by hand."
fi

# ...

DEPS=( git vim zsh fzf fd "$HOME/.nvm/nvm.sh" mc gcc java diff make less rg sed bat head chsh go node npm pyenv tree ln readlink )
MUST_DIE=0
for i in "${DEPS[@]}"
do
    check_installed $i
    if [ $? -ne 0 ]; then
        MUST_DIE=1
    fi
done

if [ $MUST_DIE -eq 1 ]; then
    warn "Please install the missing dependencies before continuing the installation!"
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
link .vimrc
link Pipfile
link .zshrc
link .zshrc.p10k
link .curlrc
link .wgetrc
link .nuget/NuGet/NuGet.Config
link .config/mc
link .config/htop
link .config/Code/User/settings.json
link .config/Code/User/keybindings.json
link .config/Code/User/settings.json "./.config/Code - OSS/User/settings.json"
link .config/Code/User/keybindings.json "./.config/Code - OSS/User/keybindings.json"

link .qmgr.sh
link .quickies/git-command.sh
link .quickies/arch-system-upgrade.sh
link .quickies/red-shift-tunnel-in-production.sh

# Setup vim
roll "Setting up vim..."
VUNDLE_DIR=$HOME/.vim/bundle/Vundle.vim
pull_or_clone_repo "Vundle" "$VUNDLE_DIR" "https://github.com/VundleVim/Vundle.vim.git"

roll "Vundle is installed and at the latest version. Installing plugins..."
vim +PluginInstall +qall &>> $LOG_FILE
if [ $? -ne 0 ]; then
    err "Failed to install Vundle plugins."
fi

vim +PluginUpdate +qall &>> $LOG_FILE
if [ $? -ne 0 ]; then
    err "Failed to update Vundle plugins."
fi

roll "All Vundle plugins have been installed & updated."
roll "Building YouCompleteMe plugin..."
(
    cd ~/.vim/bundle/youcompleteme
    ./install.sh &>> $LOG_FILE
    if [ $? -ne 0 ]; then
        err "Failed to build the YouCompleteMe plugin."
    fi
)

roll "YouCompleteMe plugin was re-built."

check_installed "code"
if [ $? -eq 0 ]; then
    roll "Installing VS Code extensions..."
    cat $DF/vs-extensions.txt | xargs -L 1 code --install-extension &>> $LOG_FILE
    if [ $? -ne 0 ]; then
        err "Failed install VS Code extensions."
    fi

    roll "Finished installing VS Code extensions."
else
    warn "VS Code not installed. Skipping extension installation."
fi

info
info "${BLUE}                                   |\      _,,,---,,_        "
info "${BLUE}                              ZZZzz /,\`.-'\`'    -.  ;-;;,_  "
info "${BLUE}                                   |,4-  ) )-,_. ,\ (  \`'-'  "
info "${BLUE}                                  '---''(_/--'  \`-'\_)       "
info
info "All done! You're good to go!"
info "Consider creating a new '~/.zshrc.local' file to hold your personal settings."
