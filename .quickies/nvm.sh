#!/bin/sh

case "$1" in
    "--query" )
        source "/usr/share/nvm/init-nvm.sh" || source "$NVM_DIR/nvm.sh" || source "$HOME/.nvm" || exit 1

        nvm ls --no-alias --no-colors | sed -n 's|.*\ \(.*\)\ \**|\1|p'
        exit 0 ;;
    "--details" )
        echo "Selects the \"$ARG\" nodejs version as active."
        exit 0 ;;
esac

nvm use $ARG