#!/bin/sh

case "$1" in
    "--query" )
        [ ! -f "$HOME/.zhistory" ] && exit 1

        cat $HOME/.zhistory | sed -n 's|.*;\(.*\)|\1|p' | grep -v quickies_menu | tail -10 
        exit 0 ;;
    "--details" )
        echo "Executes the \"$ARG\" command from the shell history."
        exit 0 ;;
esac

eval $ARG