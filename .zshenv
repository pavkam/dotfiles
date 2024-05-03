# ---------------------------------------------------------------------------
# | pavkam's zsh setup. Nothing interesting to see here, please move along! |
# |                                                                         |
# | Parts of this file are based on "manjaro-zsh-config" and others parts,  |
# | are based on many samples found all over the Internet!                  |
# |                                                                         |
# | I apologize in advance if I did not mention the sources explicitly.     |
# ---------------------------------------------------------------------------

echo ".zshenv"

# Force locale
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'
export PYTHONIOENCODING='UTF-8'
export ZSH_PYENV_QUIET=true

# variables
typeset -U PATH
typeset -U IS_ARM64_DARWIN
typeset -U IS_DARWIN
typeset -U DARWIN_HAS_BREW

export IS_ARM64_DARWIN=0
export IS_DARWIN=0
export DARWIN_HAS_BREW=0

if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin"
fi

if [ "$(uname)" = "Darwin" ]; then
    IS_DARWIN=1

    if command -v arch &> /dev/null && [ "$(arch)" = "arm64" ]; then
        IS_ARM64_DARWIN=1
    fi

    local B="/opt/homebrew/bin/brew"
    if [ -x $B ]; then
        HOMEBREW_PREFIX="$($B --prefix)"
        PATH="$HOMEBREW_PREFIX/bin:$PATH"
    fi

    if command -v brew &>/dev/null; then
        DARWIN_HAS_BREW=1

        eval "$(brew shellenv)"
        PATH="$HOMEBREW_PREFIX:$PATH"

        _gnu_version () {
                local P="$(brew --prefix)/opt/$1/libexec/gnubin"
                if [ -d "$P" ]; then
                    PATH="$P:$PATH"
                fi
            }

        _cask_version () {
            local P="$(brew --prefix $1)/bin"
            if [ -d "$P" ]; then
                PATH="$P:$PATH"
            fi
        }

        _gnu_version "gnu-sed"
        _gnu_version "grep"
        _gnu_version "coreutils"

        _cask_version "ruby"
        _cask_version "cython"
        _cask_version "curl"
        _cask_version "llvm"
        _cask_version "binutils"
    fi
fi

# Import the local configuration, if any.
local P=$HOME/.zshenv.local
if [ -f "$P" ]; then
    source "$P"
fi

# PyEnv version manager.
PYENV_ROOT="$HOME/.pyenv"
if command -v pyenv 1>/dev/null 2>&1; then
    export PYENV_ROOT
    PATH="$PYENV_ROOT/bin:$PATH"

    eval "$(pyenv init --path)"
    eval "$(pyenv virtualenv-init -)"
fi

# Java SDK manager.
SDKMAN_DIR="$HOME/.sdkman"
SDKMAN_INIT="$SDKMAN_DIR/bin/sdkman-init.sh"
if [ -s "$SDKMAN_INIT" ]; then
    export SDKMAN_DIR
    source "$SDKMAN_INIT"
fi

# NodeJS version manager.
[ -e "$NVM_DIR" ] || NVM_DIR="$HOME/.nvm"

if [ -s "/usr/share/nvm/init-nvm.sh" ]; then
    source "/usr/share/nvm/init-nvm.sh"
elif [ -e "$NVM_DIR/bin/nvm.sh" ]; then
    source "$NVM_DIR/nvm.sh"
    source "$NVM_DIR/bash_completion"
elif [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]; then
    source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
    source "$HOMEBREW_PREFIX/etc/bash_completion.d/nvm"
fi

# Ruby package manager.

if [ -s "$HOMEBREW_PREFIX/opt/chruby/share/chruby/chruby.sh" ]; then
    source $HOMEBREW_PREFIX/opt/chruby/share/chruby/chruby.sh
fi

if [ -s "$HOMEBREW_PREFIX/opt/chruby/share/chruby/auto.sh" ]; then
    source $HOMEBREW_PREFIX/opt/chruby/share/chruby/auto.sh
fi

# Prepare GO, if installed.
if command -v go &>/dev/null; then
    export GOPATH="$HOME/.go"

    if [ -d "$GOPATH/bin" ]; then
        PATH="$PATH:$GOPATH/bin"
    fi
fi

function declutter_path() {
    local -a COMPONENTS
    local COMPONENT
    local RESULT=""

    # Split PATH into individual components
    IFS=":" read -A COMPONENTS <<< $PATH

    # Use an associative array to remove duplicates
    local -A UNIQUE_COMPONENTS
    for COMPONENT in "${COMPONENTS[@]}"; do
        if [ "$COMPONENT" = "" ] || [ "$UNIQUE_COMPONENTS[$COMPONENT]" = "1" ]; then
            continue
        fi
        echo $COMPONENT

        if [ "$RESULT" = "" ]; then
            RESULT="$COMPONENT"
        else
            RESULT="$RESULT:$COMPONENT"
        fi

        UNIQUE_COMPONENTS[$COMPONENT]="1"
    done

    # Set PATH variable with unique components
    PATH=$RESULT
    echo "---------"
}

# Set a marker that the configuration was loaded. Used in .zprofile to avoid
# loading the configuration twice.
export PAVKAM_ZSH_CONFIG_SETUP=1
declutter_path
