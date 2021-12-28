# ---------------------------------------------------------------------------
# | pavkam's zsh setup. Nothing interesting to see here, please move along! |
# | Parts of this file are based on "manjaro-zsh-config" and others parts,  |
# | are based on many samples found all over the Internet!                  |
# |                                                                         |
# | I apologize in advance if I did not mention the sources explicitly      |
# ---------------------------------------------------------------------------

# Oh-My-Zsh Setup.
export ZSH="$HOME/.oh-my-zsh"

plugins=( git z fzf fd docker zsh-autosuggestions zsh-history-substring-search zsh-syntax-highlighting )

COMM=$(basename "$(cat "/proc/$PPID/comm")")
if [ "$COMM" = "login" ] || [ "$TERM" = "linux" ]; then
  export ZSH_THEME="clean"
else
  export ZSH_THEME="powerlevel10k/powerlevel10k"
fi

source $ZSH/oh-my-zsh.sh

P10K_INIT="$HOME/.zshrc.p10k"
if [ -s "$P10K_INIT" ]; then
  source $P10K_INIT
fi

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Force locale
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'
export PYTHONIOENCODING='UTF-8'

# Other settings and general options
export EDITOR='vim'
export MANPAGER='less -X'
export LESS_TERMCAP_md="${yellow}"
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

setopt correct
setopt extendedglob
setopt nocaseglob
setopt rcexpandparam
setopt nocheckjobs
setopt numericglobsort
setopt nobeep
setopt appendhistory
setopt histignorealldups
setopt autocd
setopt inc_append_history

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' rehash true
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

HISTFILE=~/.zhistory
HISTSIZE=10000
SAVEHIST=10000
WORDCHARS=${WORDCHARS//\/[&.;]}

# Keys
bindkey -e
bindkey '^[[7~' beginning-of-line
bindkey '^[[H' beginning-of-line

if [[ "${terminfo[khome]}" != "" ]]; then
  bindkey "${terminfo[khome]}" beginning-of-line
fi

bindkey '^[[8~' end-of-line
bindkey '^[[F' end-of-line

if [[ "${terminfo[kend]}" != "" ]]; then
  bindkey "${terminfo[kend]}" end-of-line
fi

bindkey '^[[2~' overwrite-mode
bindkey '^[[3~' delete-char
bindkey '^[[C'  forward-char
bindkey '^[[D'  backward-char
bindkey '^[Oc' forward-word
bindkey '^[Od' backward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^H' backward-kill-word

# Color man pages
export LESS_TERMCAP_mb=$'\E[01;32m'
export LESS_TERMCAP_md=$'\E[01;32m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;47;34m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;36m'
export LESS=-R

# bind UP and DOWN arrow keys to history substring search
zmodload zsh/terminfo

bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Arch/Manjaro-specific feaure. Offer to install missing package if command is not found.
if [[ -r /usr/share/zsh/functions/command-not-found.zsh ]]; then
    source /usr/share/zsh/functions/command-not-found.zsh
    export PKGFILE_PROMPT_INSTALL_MISSING=1
fi

function title {
  emulate -L zsh
  setopt prompt_subst

  [[ "$EMACS" == *term* ]] && return

  : ${2=$1}

  case "$TERM" in
    xterm*|putty*|rxvt*|konsole*|ansi|mlterm*|alacritty|st*)
      print -Pn "\e]2;${2:q}\a"
      print -Pn "\e]1;${1:q}\a"
      ;;
    screen*|tmux*)
      print -Pn "\ek${1:q}\e\\"
      ;;
    *)
    if [[ -n "$terminfo[fsl]" ]] && [[ -n "$terminfo[tsl]" ]]; then
      echoti tsl
      print -Pn "$1"
      echoti fsl
    fi
      ;;
  esac
}

ZSH_THEME_TERM_TAB_TITLE_IDLE="%15<..<%~%<<" #15 char left truncated PWD
ZSH_THEME_TERM_TITLE_IDLE="%n@%m:%~"

# Runs before showing the prompt
function mzc_termsupport_precmd {
  [[ "${DISABLE_AUTO_TITLE:-}" == true ]] && return
  title $ZSH_THEME_TERM_TAB_TITLE_IDLE $ZSH_THEME_TERM_TITLE_IDLE
}

# Runs before executing the command
function mzc_termsupport_preexec {
  [[ "${DISABLE_AUTO_TITLE:-}" == true ]] && return

  emulate -L zsh
  local -a cmdargs
  cmdargs=("${(z)2}")
  if [[ "${cmdargs[1]}" = fg ]]; then
    local job_id jobspec="${cmdargs[2]#%}"
    case "$jobspec" in
      <->)
        job_id=${jobspec} ;;
      ""|%|+)
        job_id=${(k)jobstates[(r)*:+:*]} ;;
      -)
        job_id=${(k)jobstates[(r)*:-:*]} ;;
      [?]*)
        job_id=${(k)jobtexts[(r)*${(Q)jobspec}*]} ;;
      *)
        job_id=${(k)jobtexts[(r)${(Q)jobspec}*]} ;;
    esac

    if [[ -n "${jobtexts[$job_id]}" ]]; then
      1="${jobtexts[$job_id]}"
      2="${jobtexts[$job_id]}"
    fi
  fi

  local CMD=${1[(wr)^(*=*|sudo|ssh|mosh|rake|-*)]:gs/%/%%}
  local LINE="${2:gs/%/%%}"

  title '$CMD' '%100>...>$LINE%<<'
}

autoload -U add-zsh-hook

add-zsh-hook precmd mzc_termsupport_precmd
add-zsh-hook preexec mzc_termsupport_preexec

# FZF-ness

FD_EXE=""
if [ "`which fdfind`" != "" ]; then
  FD_EXE="fdfind"
else [ "`which fd`" != "" ]; then
  FD_EXE="fd"
fi

if [ "$FD_EXE" != "" ]; then
  FD_OPTIONS="--follow --hidden --exclude .git --exclude node_modules"
  export FZF_DEFAULT_COMMAND="git ls-files --cached --others --exclude-standard | $FD_EXE --type f --type l $FD_OPTIONS"
  export FZF_CTRL_T_COMMAND="$FD_EXE $FD_OPTIONS"
  export FZF_ALT_C_COMMAND="$FD_EXE --type d $FD_OPTIONS"
else
  export FZF_DEFAULT_COMMAND="git ls-files --cached --others --exclude-standard | find"
  export FZF_CTRL_T_COMMAND="find"
  export FZF_ALT_C_COMMAND="find"
fi

export FZF_COMPLETION_TRIGGER='**'
export BAT_PAGER="less -R"

PREVIEW_CAT="cat"
if [ "`which bat`" != "" ]; then
  PREVIEW_CAT="bat --style=numbers --color=always"
else [ "`which batcat`" != "" ]; then
  PREVIEW_CAT="batcat --style=numbers --color=always"
fi

export FZF_DEFAULT_OPTS="
--layout=reverse
--info=inline
--height=80%
--preview '([[ -f {} ]] && (bat --style=numbers --color=always {} || cat {})) || ([[ -d {} ]] && (tree -C {} | less)) || echo {} 2> /dev/null | head -200'
--color=dark
--color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f
--color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7
--prompt='∼ ' --pointer='▶' --marker='✓'
--bind '?:toggle-preview'
--bind 'ctrl-y:execute-silent(echo {+} | xclip -selection clipboard)'
--bind 'alt-enter:execute(clear && xdg-open {+})'
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

QMGR=$HOME/.qmgr.sh
if [ -f "$QMGR" ]; then
    quickies_menu() {
        SCRIPT=$(sh -c "$QMGR --list" | fzf --height=20% --preview-window down,2,border-horizontal --preview "sh -c '$QMGR --details {}'")
        if [ "$SCRIPT" != "" ]; then
            . "$QMGR" --execute "$SCRIPT"
        fi
    }

    bindkey -s "^\`" 'quickies_menu^M'
    bindkey -s "^~" 'quickies_menu^M'
fi

# Helper aliases and functions

alias cp='cp -iv'
alias mkdir='mkdir -pv'
alias mv='mv -iv'
alias rm='rm -rf --'
alias df='df -h'
alias free='free -m'
alias decolorize='sed -r "s/\\x1B\\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g"'
alias cd..='cd ..'
alias sudo='sudo '
alias map='xargs -n1'
alias reload='exec ${SHELL} -l'
alias ts='date -d @1639018800 "+%F %T"'

epoch() {
  if [ "$1" = "" ]; then
    date '+%s'  
  else
    date -d @$1 '+%F %T'
  fi
}

# Import the local configuration, if any.
LOCAL_INIT="$HOME/.zshrc.local"
if [ -f "$LOCAL_INIT" ]; then
     source $LOCAL_INIT
fi

# And now define all other goodies.

if command -v dig &> /dev/null; then
    alias ip='dig +short myip.opendns.com @resolver1.opendns.com'
fi

if command -v xdg-open &> /dev/null; then
  function open() {
    if [ $# -eq 0 ]; then
      xdg-open .;
    else
      xdg-open "$@";
    fi;
  }
fi

# Custom imports based on installed tooling.
if command -v lpass &>/dev/null; then
	if [ "$LAST_PASS_EMAIL" != "" ]; then
		unalias pass &>/dev/null
		function pass() {
			lpass status &>/dev/null || lpass login "$LAST_PASS_EMAIL" &>/dev/null && lpass ls --sync=auto --color=never | grep -E "[0-9]{10}" | fzf --preview-window=default --preview 'lpass show `echo "{}" | sed -n "s/.*\[id\:\ \([0-9]*\)\].*/\1/p"`' | sed -n "s/.*\[id\:\ \([0-9]*\)\].*/\1/p" | xargs lpass show
		}
	fi
fi

# Java SDK manager.
SDKMAN_DIR="$HOME/.sdkman"
if [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
    export SDK_MAN
    source $SDKMAN_DIR/bin/sdkman-init.sh
fi

# NodeJS version manager.
NVM_INIT="/usr/share/nvm/init-nvm.sh"
if [ -s "$NVM_INIT" ]; then
    source $NVM_INIT
fi