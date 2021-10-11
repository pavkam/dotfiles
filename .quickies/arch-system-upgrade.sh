#!/bin/sh

case "$1" in
    "--query" )
        if [ -e "/etc/arch-release" ]; then
            exit 0
        else 
            exit 1
        fi
        ;;
    "--details" )
        echo "This script updates all the mirrors; then it upgrades all the packages, and finally, updates all AUR dependancies."
        exit 0 ;;
esac

sudo pacman-mirrors -g && sudo pamac upgrade --no-confirm && sudo yay --nodiffmenu --noeditmenu --nouseask --nocleanmenu --noupgrademenu --noconfirm