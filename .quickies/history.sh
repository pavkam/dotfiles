#!/bin/sh

case "$1" in
    "--query" )
        cat ~/.zhistory | sed -n 's|.*;\(.*\)|\1|p'  | tail -10 
        exit 0 ;;
    "--details" )
        echo "Executes the \"$ARG\" command from the shell history."
        exit 0 ;;
esac

eval $ARG