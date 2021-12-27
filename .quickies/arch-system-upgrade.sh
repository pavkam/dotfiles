#!/bin/sh

case "$1" in
    "--query" )
        [ ! -e "/etc/arch-release" ] && exit 1
        exit 0 ;;
    "--details" )
        echo "This script updates all the mirrors; then it upgrades all the packages, and finally, updates all AUR dependancies."
        exit 0 ;;
esac

sudo pacman-mirrors -g && sudo pamac upgrade --no-confirm && sudo yay -Syu --nodiffmenu --noeditmenu --nouseask --nocleanmenu --noupgrademenu --noconfirm