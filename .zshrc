# ---------------------------------------------------------------------------
# | pavkam's zsh setup. Nothing interesting to see here, please move along! |
# ---------------------------------------------------------------------------

# Oh-My-Zsh Setup.
export ZSH="$HOME/.oh-my-zsh"

plugins=( git z fzf fd docker )
export ZSH_THEME="powerlevel10k/powerlevel10k"
source $ZSH/oh-my-zsh.sh

P10K_INIT="$HOME/.zshrc.p10k"
if [ -s "$P10K_INIT" ]; then
  source $P10K_INIT
fi

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Other settings
export EDITOR='vim'

FD_OPTIONS="--follow --exclude .git --exclude node_modules"
export FZF_COMPLETION_TRIGGER='**'
export FZF_DEFAULT_COMMAND="git ls-files --cached --others --exclude-standard | fd --type f --type l $FD_OPTIONS"
export FZF_CTRL_T_COMMAND="fd $FD_OPTIONS"
export FZF_ALT_C_COMMAND="fd --type d $FD_OPTIONS"
export BAT_PAGER="less -R"

export FZF_DEFAULT_OPTS="
--layout=reverse
--info=inline
--height=80%
--multi
--preview-window=:hidden
--preview '([[ -f {} ]] && (bat --style=numbers --color=always {} || cat {})) || ([[ -d {} ]] && (tree -C {} | less)) || echo {} 2> /dev/null | head -200'
--color='hl:148,hl+:154,pointer:032,marker:010,bg+:237,gutter:008'
--prompt='∼ ' --pointer='▶' --marker='✓'
--bind '?:toggle-preview'
--bind 'ctrl-a:select-all'
--bind 'ctrl-y:execute-silent(echo {+} | pbcopy)'
--bind 'ctrl-v:execute(xdg-open {+})'
"

fzf_compgen_path() {
    fd . "$1"
}

_fzf_compgen_dir() {
    fd --type d . "$1"
}

fif() {
  if [ ! "$#" -gt 0 ]; then
    echo "Need a string to search for!";
    return 1;
  fi
  
  rg --files-with-matches --no-messages "$1" | fzf $FZF_PREVIEW_WINDOW --preview "rg --ignore-case --pretty --context 10 '$1' {}"
}

unalias z 2> /dev/null
z() {
    [ $# -gt 0 ] && _z "$*" && return
    cd "$(_z -l 2>&1 | fzf --height 40% --nth 2.. --reverse --inline-info +s --tac --query "${*##-* }" | sed 's/^[0-9,.]* *//')"
}

SDKMAN_DIR="$HOME/.sdkman"
if [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
    export SDK_MAN
    source $SDKMAN_DIR/bin/sdkman-init.sh
fi

NVM_INIT="/usr/share/nvm/init-nvm.sh"
if [ -s "$NVM_INIT" ]; then
    source $NVM_INIT
fi

# Import the local configuration
LOCAL_INIT="$HOME/.zshrc.local"
if [ -s "$LOCAL_INIT" ]; then
     source $LOCAL_INIT
fi
