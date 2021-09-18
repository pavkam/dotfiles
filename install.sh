#!/bin/bash
# ---------------------------------------------------------------------------
# | pavkam's zsh setup. Nothing interesting to see here, please move along! |
# ---------------------------------------------------------------------------

# "Die" handling. Wil be used to exit the shell when requested by child script (functions).
trap "exit 1" TERM
export TOP_PID=$$

DFN=`realpath $0`
DF=`dirname $DFN`

function die() {
    tput setaf 1 && echo "Terminating due to an error!"

    if [ $$ -eq $TOP_PID ]; then
        exit 1
    else
        kill -s TERM $TOP_PID
    fi
}

function whoops() {
    >&2 tput setaf 1 && echo "[WHOOPS] $1"
    die
}
 
function err() {
    >&2 tput setaf 1 && echo "[ERR] $1"   
    die
}

function warn() {
    >&2 tput setaf 3 && echo "[WARN] $1"   
}


function info() {
    tput sgr0 && echo "$1"   
}


function link() {
    FROM=$1
    TO=$2
    if [ "$FROM" = "" ]; then
        whoops "LINK: Expected at least one  argument to function."
    fi

    if [ "$TO" == "" ]; then
        TO=$FROM
    fi

    if [ ! -e "$DF/$FROM" ]; then
        whoops "LINK: The file or directory '$DF/$FROM' does not exist."    
    fi

    info "LINK: Creating a symlink from '$DF/$FROM' to '$HOME/$TO'..."

    HAS_BACKUP=0
    if [ -e "$HOME/$TO" ]; then
        warn "LINK: The file or directory '$HOME/$TO' already exists. Backing up and replacing..."

        rm -r -f -d "$HOME/$TO.old" >/dev/null 2>/dev/null
        mv "$HOME/$TO" "$HOME/$TO.old" >/dev/null 2>/dev/null
        if [ $? -ne 0 ]; then
            err "LINK: Failed to backup file '$HOME/$TO'."
        fi

        HAS_BACKUP=1
    fi

    DIR_OF_TO="`dirname -- '$HOME/$TO'`"
    if [ ! -d "$DIR_OF_TO" ]; then
        info "LINK: The destination directory '$DIR_OF_TO' does not exist. Creating..."
        mkdir -p "$DIR_OF_TO" >/dev/null 2>/dev/null
        if [ $? -ne 0 ]; then
            err "LINK: Failed to create the destination directory '$DIR_OF_TO'."
        fi

        info "LINK: Created the destination directory '$DIR_OF_TO'."
    fi

    ln -s "$DF/$FROM" "$HOME/$TO" 2>/dev/null

    if [ $? -ne 0 ]; then
        if [ $HAS_BACKUP -eq 1 ]; then
            mv "$HOME/$TO.old" "$HOME/$TO" >/dev/null 2>/dev/null
            if [ $? -ne 0 ]; then
                warn "LINK: Failed to restore file '$HOME/$TO' from its backup."
            fi
        fi

        err "LINK: Symlink between '$DF/$FROM' and '$HOME/$TO' failed."
    else
        info "LINK: Symlink between '$DF/$FROM' and '$HOME/$TO' created."
    fi
}

function check_installed() {
    if [ "$1" = "" ]; then
        whoops "DEP: Expected one argument to function."
    fi

    which "$1" >/dev/null 2>/dev/null
    if [ $? -ne 0 ] && [ ! -f "$1" ]; then
        warn "DEP: Command '$1' not found."
        return 1
    else
        info "DEP: Command '$1' has been found."
        return 0
    fi    
}

info "Welcome to pavkam's .dotfiles installer. Hope you enjoy the process."
info "This installer comes with absolutely no guarantees!"
info 

# Check dependencies (commands that should be installed)
info "DEP: Checking dependencies..."
DEPS=( git vim zsh fzf fd "$HOME/.nvm/nvm.sh" mc gcc java diff make less rg sed bat head chsh go node npm pyenv )
MUST_DIE=0
for i in "${DEPS[@]}"
do
    check_installed $i
    if [ $? -ne 0 ]; then
        MUST_DIE=1
    fi
done

if [ $MUST_DIE -eq 1 ]; then
    warn "DEP: Please install the missing dependencies before continuing the installation!"
    die
else
    info "DEP: All dependencies are installed."
fi 

# Setup the shell & Oh-My-Zsh

info "SHELL: Checking the current shell..."
SHELL_NAME=`basename -- $SHELL`
if [ "$SHELL_NAME" != "zsh" ]; then
    warn "SHELL: The current shell ('$SHELL_NAME') is not zsh. Setting zsh as default..."
    chsh -s $(which zsh)
    if [ $? -ne 0 ]; then
        err "SHELL: Shell switching failed!"
    fi
else
    info "SHELL: Nothing to do - current shell is already set to zsh."
fi

OMZ_DIR=${ZSH_CUSTOM:-$HOME/.oh-my-zsh}
info "SHELL: Installing Oh-My-Zsh..."   
if [ -d "$OMZ_DIR" ]; then
    warn "SHELL: Oh-My-Zsh already installed. Pulling..."
    (
        cd "$OMZ_DIR"
        git pull >/dev/null 2>/dev/null
        if [ $? -ne 0 ]; then
            err "SHELL: Failed to update Oh-My-Zsh git repository."
        else
            info "SHELL: Updated the Oh-My-Zsh git repository to the latest version."
        fi
    )
else
    info "SHELL: Cloning Oh-My-Zsh from GitHub..."
    git clone "https://github.com/ohmyzsh/ohmyzsh.git" "$OMZ_DIR" >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        err "SHELL: Failed to clone Oh-My-Zsh git repository."
    fi

    info "SHELL: Cloned the Oh-My-Zsh git repository."
fi

POWERLEVEL_10K_DIR=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
if [ -d "$POWERLEVEL_10K_DIR" ]; then
    warn "SHELL: PowerLevel10K theme already installed. Pulling..."
    (
        cd "$POWERLEVEL_10K_DIR"
        git pull >/dev/null 2>/dev/null
        if [ $? -ne 0 ]; then
            err "SHELL: Failed to update PowerLevel10K git repository."
        else
            info "SHELL: Updated the PowerLevel10K git repository to the latest version."
        fi
    )
else
    info "SHELL: Cloning PowerLevel10K from GitHub..."
    git clone --depth=1 "https://github.com/romkatv/powerlevel10k.git" "$POWERLEVEL_10K_DIR" >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        err "SHELL: Failed to clone PowerLevel10K git repository."
    fi

    info "SHELL: Cloned the PowerLevel10K git repository."
fi

# Create all the symlinks
info "LINK: Creating all symlinks..."
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
info "VIM: Setting up vim..."
VUNDLE_DIR=$HOME/.vim/bundle/Vundle.vim
if [ -d "$VUNDLE_DIR" ]; then
    warn "VIM: Vundle repository already installed. Pulling..."
    (
        cd $VUNDLE_DIR
        git pull >/dev/null 2>/dev/null
        if [ $? -ne 0 ]; then
            err "VIM: Failed to update the Vundle git repository."
        fi
    )
else
    info "VIM: Cloning Vundle from GitHub..."
    git clone "https://github.com/VundleVim/Vundle.vim.git" "$VUNDLE_DIR" >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        err "VIM: Failed to clone Vundle git repository."
    fi
fi

info "VIM: Vundle is installed and at the latest version. Installing plugins..."
vim +PluginInstall +qall >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    err "VIM: Failed to install Vundle plugins."
fi

vim +PluginUpdate +qall >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    err "VIM: Failed to update Vundle plugins."
fi

info "VIM: All Vundle plugins have been installed & updated."
info "VIM: Building YouCompleteMe plugin..."
(
    cd ~/.vim/bundle/youcompleteme
    ./install.sh >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        err "VIM: Failed to build the YCM plugin."
    fi
)

info "All done! You're good to go!"
