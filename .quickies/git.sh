#!/bin/sh

case "$1" in
    "--query" )
        [ ! -d "./.git" ] && exit 1
        
        echo "commit"
        echo "status"
        echo "add-all"
        echo "yolo"
        echo "pull-all"
        echo "sync-everything"
        echo "log"
        echo "select-branch"
        
        exit 0 ;;
    "--details" )
        echo "Executes the \"$ARG\" command(s) in the current git directory."
        exit 0 ;;
esac

case "$ARG" in
    "commit" )
        git commit ;;
    "status" )
        git st ;;
    "add-all" )
        git aa . ;;
    "yolo" )
        git yolo ;;
    "pull-all" )
        git pulla ;;
    "sync-everything" )
        git sync ;;
    "log" )
        git lc ;;
    "select-branch" )
        git bs ;;
esac