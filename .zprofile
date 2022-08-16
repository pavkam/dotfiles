# ---------------------------------------------------------------------------
# | pavkam's zsh setup. Nothing interesting to see here, please move along! |
# |                                                                         |
# | Parts of this file are based on "manjaro-zsh-config" and others parts,  |
# | are based on many samples found all over the Internet!                  |
# |                                                                         |
# | I apologize in advance if I did not mention the sources explicitly.     |
# ---------------------------------------------------------------------------

if [ $IS_DARWIN -eq 1 ] && [ -s "$HOME/.zshenv" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    . "$HOME/.zshenv"
fi
