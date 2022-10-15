# ---------------------------------------------------------------------------
# | pavkam's zsh setup. Nothing interesting to see here, please move along! |
# |                                                                         |
# | Parts of this file are based on "manjaro-zsh-config" and others parts,  |
# | are based on many samples found all over the Internet!                  |
# |                                                                         |
# | I apologize in advance if I did not mention the sources explicitly.     |
# ---------------------------------------------------------------------------

typeset -U PATH

# Force locale
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'
export PYTHONIOENCODING='UTF-8'
export ZSH_PYENV_QUIET=true

export IS_ARM64_DARWIN=0
export IS_DARWIN=0

local P="$HOME/.local/bin"
if [ -d "$P" ]; then
    export PATH="$P:$PATH"
fi

DARWIN_HAS_BREW=0
if [ "`uname`" = "Darwin" ]; then
    IS_DARWIN=1

    if command -v arch &> /dev/null && [ "`arch`" = "arm64" ]; then
        IS_ARM64_DARWIN=1
    fi

    if command -v brew &>/dev/null; then
        DARWIN_HAS_BREW=1
    fi
fi

eval "$(/opt/homebrew/bin/brew shellenv)"

if [ $DARWIN_HAS_BREW -eq 1 ]; then
    _gnu_version () {
        local P="$(brew --prefix)/opt/$1/libexec/gnubin"
        if [ -d "$P" ]; then
            export PATH="$P:$PATH"
        fi
    }

    _gnu_version "gnu-sed"
    _gnu_version "grep"
    _gnu_version "coreutils"
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
    export PATH="$PYENV_ROOT/bin:$PATH"

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

if [ -s "$HOMEBREW_PREFIX/opt/chruby/share/chruby/chruby.sh" ]; then
    source $HOMEBREW_PREFIX/opt/chruby/share/chruby/chruby.sh
fi

if [ -s "$HOMEBREW_PREFIX/opt/chruby/share/chruby/auto.sh" ]; then
    source $HOMEBREW_PREFIX/opt/chruby/share/chruby/auto.sh
fi