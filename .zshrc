# ---------------------------------------------------------------------------
# | pavkam's zsh setup. Nothing interesting to see here, please move along! |
# | Parts of this file are based on "Manjaro-zsh-config" and others parts,  |
# | are based on many samples found all over the Internet!                  |
# |                                                                         |
# | I apologize in advance if I did not mention the sources explicitly      |
# ---------------------------------------------------------------------------

# Oh-My-Zsh Setup.
export ZSH="$HOME/.oh-my-zsh"

plugins=( git z fzf docker zsh-autosuggestions zsh-history-substring-search zsh-syntax-highlighting sdk vscode )

autoload -Uz compinit
compinit

COMM=$(basename "$(cat "/proc/$PPID/comm" 1>/dev/null 2>/dev/null)")
if [ "$COMM" = "login" ] || [ "$TERM" = "linux" ] || [ "$MC_SID" != "" ]; then
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

# Other settings and general options
export EDITOR='nvim'
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

# Arch/Manjaro-specific feature. Offer to install missing package if command is not found.
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
    xterm*|putty*|rxvt*|konsole*|ansi|mlterm*|alacritty|st|kitty*)
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

ZSH_THEME_TERM_TAB_TITLE_IDLE="%15<..<%~%<<" #15 char left truncated pwd
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

load-nvmrc() {
  local nvmrc_path
  nvmrc_path="$(nvm_find_nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version
    nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
      nvm use
    fi
  elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}

add-zsh-hook precmd mzc_termsupport_precmd
add-zsh-hook preexec mzc_termsupport_preexec
add-zsh-hook chpwd load-nvmrc

load-nvmrc

# aliases
alias ls='ls --color'
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
alias h=cat $HOME/.zhistory | sed -n 's|.*;\(.*\)|\1|p' | grep -v quickies_menu | tail -10

# VIM stuff
alias vi=nvim
alias vim=nvim
alias :qa=exit
alias :q=exit

# fzf stuff
if command -v fzf &>/dev/null; then
    eval "$(fzf --zsh)"

    FD_EXE=""
    if command -v fdfind &>/dev/null; then
        FD_EXE=fdfind
    else command -v fd &>/dev/null then
        FD_EXE=fd
    fi

    export BAT_PAGER="less -R"

    PREVIEW_CAT="cat"
    if command -v bat &>/dev/null; then
        PREVIEW_CAT="bat --style=numbers --color=always"
    elif command -v batcat &>/dev/null; then
        PREVIEW_CAT="batcat --style=numbers --color=always"
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
        --bind 'alt-enter:execute(clear && open {+})'
    "

    function fzf_compgen_path() {
        fd . "$1"
    }

    function _fzf_compgen_dir() {
        fd --type d . "$1"
    }

    function fif() {
        if [ ! "$#" -gt 0 ]; then
            echo " Need a string to search for!";
            return 1;
        fi

        rg --files-with-matches --no-messages "$1" | fzf $FZF_PREVIEW_WINDOW --preview "rg --ignore-case --pretty --context 10 '$1' {}"
    }

    unalias z &> /dev/null
    function z() {
        [ $# -gt 0 ] && zshz "$*" && return
        cd "$(zshz -l 2>&1 | fzf --height 40% --nth 2.. --reverse --inline-info +s --tac --query "${*##-* }" | sed 's/^[0-9,.]* *//')"
    }
fi

# Helper aliases and functions

if command -v heroku &> /dev/null; then
    # Heroku autocomplete setup
    HEROKU_AC_ZSH_SETUP_PATH=~/Library/Caches/heroku/autocomplete/zsh_setup && test -f $HEROKU_AC_ZSH_SETUP_PATH && source $HEROKU_AC_ZSH_SETUP_PATH;

    heroku-env() {
        # Check for correct number of arguments
        if [ "$#" -lt 2 ]; then
            echo " Usage: heroku-env <Heroku App Name> \"<Command to Run>\" [Exclude Var Regex]"
            return 1
        fi

        # Check Heroku session
        if ! heroku auth:whoami &> /dev/null; then
            echo " Heroku CLI is not logged in or the authorization has expired. Please log in or renew your authorization." >&2
            return 1
        fi

        APP_NAME=$1
        COMMAND=$2
        EXCLUDE=$3

        echo " Retrieving environment variables from app \"$APP_NAME\"..."

        # Get the environment variables from Heroku
        ENV_VARS=$(heroku config -s -a "$APP_NAME" 2>&1 | grep -vE "heroku update available")

        # Check if heroku config command was successful
        if [ $? -ne 0 ]; then
            echo " Failed to retrieve environment variables from Heroku." >&2
            return 1
        fi

        if [ "$EXCLUDE" != "" ]; then
            # Filter out unwanted variables (HEROKU_*, DD_*, ENVIRONMENT)
            ENV_VARS=$(echo "$ENV_VARS" | grep -vE "^($EXCLUDE)=")
        fi

        echo "$ENV_VARS" | awk -F '=' '{print "export " $1 "='\''" $2 "'\''"}'
        EXPORT_COMMANDS=$(echo "$ENV_VARS" | awk -F '=' '{print "export " $1 "='\''" $2 "'\''"}')


        echo " Running command \"$COMMAND\" with environment from app \"$APP_NAME\"..."
        $SHELL -c "$EXPORT_COMMANDS; $COMMAND"
    }
fi

local SESSION_MANAGER=""
if [ "$TMUX" != "" ]; then
    SESSION_MANAGER="tmux"
elif [ "$TERM" = "xterm-kitty" ]; then
    SESSION_MANAGER="kitty"
fi

ss() {
    local SESSIONS=""
    if [ "$SESSION_MANAGER" = "tmux" ]; then
        tmux ls &>/dev/null && SESSIONS=$(tmux ls -F "#{session_name}")
    fi

    local PROJECTS=$(
        [ "$PROJECTS_ROOT" != "" ] && fd -c never --follow --hidden --no-ignore --relative-path --base-directory $PROJECTS_ROOT .git$ -t directory -E .github | xargs dirname
    )

    local OPTIONS=$(
        [ "$SESSIONS" != "" ] && echo $SESSIONS
        [ "$PROJECTS" != "" ] && echo $PROJECTS
        echo "+new"
    )

    OPTIONS=$(echo "$OPTIONS" | sort | uniq)
    local SESSION=""

    if [ "$SESSION_MANAGER" = "tmux" ]; then
        SESSION=$(echo $OPTIONS | fzf --reverse --preview-window 'right:80%:nohidden' --preview="[ '{}' != '+new' ] && tmux capture-pane -e -pt {} 2> /dev/null || echo 'Session not running'")
    elif [ "$SESSION_MANAGER" = "kitty" ]; then
        SESSION=$(echo $OPTIONS | fzf --reverse)
    fi

    if [ "$SESSION" = "+new" ]; then
        echo -ne " Enter session name (empty to cancel): "
        read SESSION

        SESSION=$(echo "$SESSION" | sed 's/[^a-zA-Z0-9\/]/_/g')

        if [ "$SESSION" != "" ]; then
            if [ "$SESSION_MANAGER" = "tmux" ]; then
                tmux new -d -s "$SESSION" && tmux switch -t "$SESSION"
            elif [ "$SESSION_MANAGER" = "kitty" ]; then
                kitten @ launch --type=tab --title="$SESSION"
            fi
        fi
    elif [ "$SESSION" != "" ]; then
        title "$SESSION_MANAGER" "$SESSION"

        DIR="${PROJECTS_ROOT}/$SESSION"
        SESSION=$(echo "$SESSION" | sed 's/[^a-zA-Z0-9\/]/_/g')

        if [ "$SESSION_MANAGER" = "tmux" ]; then
            if tmux has -t "$SESSION" &> /dev/null; then
                tmux switch -t "$SESSION"
            else
                tmux new -d -s "$SESSION" -c "$DIR" && tmux switch -t "$SESSION"
            fi
        elif [ "$SESSION_MANAGER" = "kitty" ]; then
            kitten @ launch --type=tab --title="$SESSION" --cwd="$DIR"
        fi
    fi
}

epoch() {
  if [ "$1" = "" ]; then
    date '+%s'
  else
    date -d @$1 '+%F %T'
  fi
}

if [ "$JOURNAL_ROOT" != "" ]; then
    journal() {
        local DATE=$(date +%Y-%m-%d)
        local FILE="$JOURNAL_ROOT/$DATE.md"

        if [ ! -f "$FILE" ]; then
            echo "# Diary entry for [$DATE]\n\n---\n*Until next time, Mr. Diary...*" > "$FILE"
        fi

        nvim "$FILE"
    }
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

###-begin-npm-completion-###
#
# npm command completion script
#
# Installation: npm completion >> ~/.bashrc  (or ~/.zshrc)
# Or, maybe: npm completion > /usr/local/etc/bash_completion.d/npm
#

if type complete &>/dev/null; then
  _npm_completion () {
    local words cword
    if type _get_comp_words_by_ref &>/dev/null; then
      _get_comp_words_by_ref -n = -n @ -n : -w words -i cword
    else
      cword="$COMP_CWORD"
      words=("${COMP_WORDS[@]}")
    fi

    local si="$IFS"
    if ! IFS=$'\n' COMPREPLY=($(COMP_CWORD="$cword" \
                           COMP_LINE="$COMP_LINE" \
                           COMP_POINT="$COMP_POINT" \
                           npm completion -- "${words[@]}" \
                           2>/dev/null)); then
      local ret=$?
      IFS="$si"
      return $ret
    fi
    IFS="$si"
    if type __ltrim_colon_completions &>/dev/null; then
      __ltrim_colon_completions "${words[cword]}"
    fi
  }

  complete -o default -F _npm_completion npm
elif type compdef &>/dev/null; then
  _npm_completion() {
    local si=$IFS
    compadd -- $(COMP_CWORD=$((CURRENT-1)) \
                 COMP_LINE=$BUFFER \
                 COMP_POINT=0 \
                 npm completion -- "${words[@]}" \
                 2>/dev/null)
    IFS=$si
  }

  compdef _npm_completion npm
elif type compctl &>/dev/null; then
  _npm_completion () {
    local cword line point words si
    read -Ac words
    read -cn cword
    let cword-=1
    read -l line
    read -ln point
    si="$IFS"
    if ! IFS=$'\n' reply=($(COMP_CWORD="$cword" \
                       COMP_LINE="$line" \
                       COMP_POINT="$point" \
                       npm completion -- "${words[@]}" \
                       2>/dev/null)); then

      local ret=$?
      IFS="$si"
      return $ret
    fi
    IFS="$si"
  }
  compctl -K _npm_completion npm
fi
###-end-npm-completion-###


# Import the local configuration, if any.
if [ -f "$HOME/.zshrc.local" ]; then
  source "$HOME/.zshrc.local"
fi

# Little helper
if command -v thefuck &> /dev/null; then
  eval $(thefuck --alias)
fi

# AWS
if command -v awsume &> /dev/null; then
    alias awsume=". awsume"
fi

# Mac-specific stuff
if [ $IS_ARM64_DARWIN -eq 1 ]; then
    if [ $DARWIN_HAS_BREW -eq 0 ]; then
        alias brew='/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    fi

  alias x64="arch --x86_64"
  if [ -x "/usr/local/Homebrew/bin/brew" ]; then
    alias x64-brew='arch --x86_64 /usr/local/Homebrew/bin/brew'
  else
    alias x64-brew='arch --x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"'
  fi
fi

# Kubernetes
if command -v kubectl &> /dev/null; then
    kpods () {
        if [ "$1" != "" ]; then
            kubectl get pods -n $1
        else
            kubectl get pods --all-namespaces
        fi
    }

    kpod () {
        if [ "$2" != "" ]; then
            pods $2 | sed -n "s/^\($1[[:alnum:],-]\{1,\}\)[[:space:]]\{1,\}.\{1,\}$/\1/p"
        else
            pods | sed -n "s/^.\{1,\}[[:space:]]\{1,\}\($1[[:alnum:],-]\{1,\}\)[[:space:]]\{1,\}.\{1,\}$/\1/p"
        fi
    }
fi
