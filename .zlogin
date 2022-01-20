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

# Import the local configuration, if any.
LOCAL_INIT="$HOME/.zshrc.local"
if [ -f "$LOCAL_INIT" ]; then
     source $LOCAL_INIT
fi

# Java SDK manager.
SDKMAN_DIR="$HOME/.sdkman"
if [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
    export SDK_MAN
    source $SDKMAN_DIR/bin/sdkman-init.sh
fi

# NodeJS version manager.
NVM_INIT="/usr/share/nvm/init-nvm.sh"
[ -e "$NVM_DIR" ] || NVM_DIR="$HOME/.nvm"

if [ -s "$NVM_INIT" ]; then
  source "$NVM_INIT"
elif [ -e "$NVM_DIR/bin/nvm.sh" ]; then
  source "$NVM_DIR/nvm.sh"
  source "$NVM_DIR/bash_completion"
fi

# PyEnv version manager.
PYENV_ROOT="$HOME/.pyenv"
if command -v pyenv 1>/dev/null 2>&1; then
  export PYENV_ROOT
  export PATH="$PYENV_ROOT/bin:$PATH"

  eval "$(pyenv init --path)"
fi