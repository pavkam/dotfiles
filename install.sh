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

# "Die" handling. Wil be used to exit the shell when requested by child script (functions).
trap "exit 1" TERM
export TOP_PID=$$

DFN=`realpath $0`
DF=`dirname $DFN`

function die() {
    echo "Terminating due to an error!"

    if [ $$ -eq $TOP_PID ]; then
        exit 1
    else
        kill -s TERM $TOP_PID
    fi
}

# Colors and output.
RED=`tput setaf 1`
BROWN=`tput setaf 3`
NORMAL=`tput sgr0`
CLEARRET="\r`tput el`"
ROLLING=0

function whoops() {
    if [ $ROLLING -eq 1 ]; then
        echo
    fi

    echo "Whoops: $1" >> $LOG_FILE
    echo "$RED      Whoops: $1"
    die
}
 
function err() {
    if [ $ROLLING -eq 1 ]; then
        echo
    fi

    echo "Error: $1" >> $LOG_FILE
    echo "$RED      Error: $1"
    die
}

function warn() {
    if [ $ROLLING -eq 1 ]; then
        echo
    fi

    echo "Warning: $1" >> $LOG_FILE
    echo "$BROWN    Warning: $1"
    ROLLING=0
}

function info() {
    if [ $ROLLING -eq 1 ]; then
        echo
    fi

    echo "$1" >> $LOG_FILE
    echo "${NORMAL}$1"   
    ROLLING=0
}

function roll() {
    echo "$1" >> $LOG_FILE
    echo -ne "${CLEARRET}${NORMAL}$1"
    ROLLING=1
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
    if [ -e "$HOME/$TO" ]; then
        warn "The file or directory '$HOME/$TO' already exists. Backing up and replacing..."

        rm -r -f -d "$HOME/$TO.old" >/dev/null 2>/dev/null
        mv "$HOME/$TO" "$HOME/$TO.old" >/dev/null 2>/dev/null
        if [ $? -ne 0 ]; then
            err "Failed to backup file '$HOME/$TO'."
        fi

        HAS_BACKUP=1
    fi

    DIR_OF_TO=`dirname -- "$HOME/$TO"`
    if [ ! -d "$DIR_OF_TO" ]; then
        roll "The destination directory '$DIR_OF_TO' does not exist. Creating..."
        mkdir -p "$DIR_OF_TO" >/dev/null 2>/dev/null
        if [ $? -ne 0 ]; then
            err "Failed to create the destination directory '$DIR_OF_TO'."
        fi

        roll "Created the destination directory '$DIR_OF_TO'."
    fi

    ln -s "$DF/$FROM" "$HOME/$TO" 2>/dev/null

    if [ $? -ne 0 ]; then
        if [ $HAS_BACKUP -eq 1 ]; then
            mv "$HOME/$TO.old" "$HOME/$TO" >/dev/null 2>/dev/null
            if [ $? -ne 0 ]; then
                warn "LINK: Failed to restore file '$HOME/$TO' from its backup."
            fi
        fi

        err "Symlink between '$DF/$FROM' and '$HOME/$TO' failed."
    else
        roll "Symlink between '$DF/$FROM' and '$HOME/$TO' created."
    fi
}

function check_installed() {
    if [ "$1" = "" ]; then
        whoops "Expected one argument to function."
    fi

    which "$1" >/dev/null 2>/dev/null
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
        warn "$NAME is already installed. Pulling..."
        (
            cd "$DIR"
            git pull >/dev/null 2>/dev/null
            if [ $? -ne 0 ]; then
                err "Failed to update $NAME git repository."
            else
                roll "Updated the $NAME git repository to the latest version."
            fi
    )
    else
        roll "Cloning $NAME from '$URL'..."
        git clone "$URL" "$DIR" >/dev/null 2>/dev/null
        if [ $? -ne 0 ]; then
            err "Failed to clone $NAME git repository."
        fi

        roll "Cloned the $NAME repository into '$DIR'."
    fi
}

function is_package_installed() {
    if [ "$1" = "" ]; then
        whoops "Expected one arguments to function."
    fi

    roll "Checking if package '$1' is installed..."
    pacman -Q "$1" >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        roll "Package '$1' not installed."
        return 1
    else
        roll "Package '$1' is already installed."
        return 0
    fi
}

 function install_packages() {
    if [ "$1" = "" ]; then
        whoops "Expected one arguments to function."
    fi

    warn "Installing packages ['$1']..."
    sudo pacman -S --noconfirm $1 >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        err "Failed to install one or more packages from the list ['$1']."
    fi
}
 
info ".----------------------------------------------------------------------."
info "| Welcome to pavkam's .dotfiles installer. Hope you enjoy the proces!  |"
info "| This installer will perform the following changes:                   |"
info "|     *   Installs dependencies (on Arch-based distros),               |"
info "|     *   Configures zsh, oh-my-zsh and plugins,                       |"
info "|     *   Configures git and its settings                              |"
info "|     *   Confugures vim, Vundle and plugins                           |"
info ":----------------------------------------------------------------------:"
info "| ${RED}WARNING: This installer comes with absolutely no guarantees!${NORMAL}         |"
info "| ${RED}Please backup your home directory for safety reasons.${NORMAL}                |"
info "------------------------------------------------------------------------"
info

# Check dependencies (commands that should be installed)
roll "Checking dependencies..."

PACKS=(
    yay zsh vim git fd mc make diffutils less ripgrep sed bat util-linux nodejs npm nvm pyenv tree gcc go automake binutils bc 
    bash bzip2 cmake coreutils curl cython dialog docker htop llvm lua lz4 mono perl pyenv python python2 ruby wget 
    zip dotnet-runtime dotnet-sdk
)

TO_INSTALL=""
for i in "${PACKS[@]}"
do
    is_package_installed $i
    if [ $? -ne 0 ]; then
        TO_INSTALL="$TO_INSTALL $i"
    fi
done

if [ "$TO_INSTALL" != "" ]; then
    install_packages "$TO_INSTALL"
fi

# ...

DEPS=( git vim zsh fzf fd "$HOME/.nvm/nvm.sh" mc gcc java diff make less rg sed bat head chsh go node npm pyenv tree )
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
link .nuget/NuGet/NuGet.Config
link .config/zoomus.conf
link .config/vlc
link .config/qt5ct
link .config/nautilus
link .config/mc
link .config/lutris
link .config/htop
link .config/hexchat
link .config/caffeine
link .config/Pinta
link .config/Kvantum
link .config/Code/User/settings.json
link .config/Code/User/settings.json "./.config/Code - OSS/User/settings.json"

# Setup vim
roll "Setting up vim..."
VUNDLE_DIR=$HOME/.vim/bundle/Vundle.vim
pull_or_clone_repo "Vundle" "$VUNDLE_DIR" "https://github.com/VundleVim/Vundle.vim.git"

roll "Vundle is installed and at the latest version. Installing plugins..."
vim +PluginInstall +qall >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    err "Failed to install Vundle plugins."
fi

vim +PluginUpdate +qall >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    err "Failed to update Vundle plugins."
fi

roll "All Vundle plugins have been installed & updated."
roll "Building YouCompleteMe plugin..."
(
    cd ~/.vim/bundle/youcompleteme
    ./install.sh >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        err "VIM: Failed to build the YCM plugin."
    fi
)

roll "All done! You're good to go!"
