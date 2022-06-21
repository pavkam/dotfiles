# ---------------------------------------------------------------------------
# | pavkam's zsh setup. Nothing interesting to see here, please move along! |
# |                                                                         |
# | Parts of this file are based on "manjaro-zsh-config" and others parts,  |
# | are based on many samples found all over the Internet!                  |
# |                                                                         |
# | I apologize in advance if I did not mention the sources explicitly.     |
# ---------------------------------------------------------------------------

# Force locale
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'
export PYTHONIOENCODING='UTF-8'
export ZSH_PYENV_QUIET=true

export IS_ARM64_DARWIN=0
export IS_DARWIN=0

local P="$HOME/.local/bin"
if [ -d "$P" ]; then
    export PATH="$PATH:$P"
fi

if [ "`uname`" = "Darwin" ]; then
    IS_DARWIN=1

    if command -v arch &> /dev/null && [ "`arch`" = "arm64" ]; then
        IS_ARM64_DARWIN=1
    fi
fi

if [ $IS_DARWIN -eq 1 ] && command -v brew &>/dev/null; then
    _gnu_version () {
        local P="$(brew --prefix)/opt/$1/libexec/gnubin"
        if [ -d "$P" ]; then
            PATH="$P:$PATH"
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