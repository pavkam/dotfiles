#!/bin/sh
# ---------------------------------------------------------------------------
# | Part of pavkam's .dotfiles.                                             |
# |                                                                         |
# | This specific file is a helper used by the "q" command of zsh to manage |
# | quickie scripts. See ".quickies" for more details                       |
# ---------------------------------------------------------------------------


QUICKIES_DIR=~/.quickies
case "$1" in
    "--list" )
        # List all scripts that can run in for the current path.
        for script in $QUICKIES_DIR/*.sh; do
            if [ ! -x "$script" ]; then
                continue
            fi

            K=`sh -c "$script --query"`
            if [ $? -eq 0 ]; then
              FN=`basename "$script"`

              if [ "$K" != "" ]; then
                while IFS= read -r op; do
                  echo "${FN%.*}:${op}"
                done <<< "$K"
              else
                echo "${FN%.*}"
              fi

            fi
        done

        exit 0 ;;
    "--details" )
        SCRIPT=$2
        if [ "$SCRIPT" = "" ]; then
            echo "No suitable quickie escript name has been provided to query details for."
            exit 1
        fi

        ARG="$(cut -d':' -f2 <<< $SCRIPT)"
        SCRIPT="$(cut -d':' -f1 <<< $SCRIPT)"

        sh -c "$QUICKIES_DIR/$SCRIPT.sh --details $ARG"
        if [ $? -ne 0 ]; then
            echo "Failed to obtain details for the given quickie script."
            exit 1
        fi

        exit 0 ;;
    "--execute" )
        SCRIPT=$2
        if [ "$2" = "" ]; then
            echo "No suitable quickie script name has been provided for execution."
            return 1
        fi

        ARG="$(cut -d':' -f2 <<< $SCRIPT)"
        SCRIPT="$(cut -d':' -f1 <<< $SCRIPT)"

         # This part of the code is "magical" because its being used as a sourced script.
        . "$QUICKIES_DIR/$SCRIPT.sh"

        return $? ;;
esac

echo "Invalid command: $1"
exit 1
