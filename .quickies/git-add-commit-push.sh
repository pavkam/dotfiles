#!/bin/sh

case "$1" in
    "--query" )
        if [ -d "./.git" ]; then
            exit 0
        else 
            exit 1
        fi
        ;;
    "--details" )
        echo "This script runs git and adds, commits and then pushes all new changes in one go! YOLO!"
        exit 0 ;;
esac

git add . && git commit && git push
