#!/bin/sh

QUICKIES_DIR=~/.quickies
case "$1" in
    "--list" )
        # List all scripts that can run in for the current path.
        for script in $QUICKIES_DIR/*.sh; do
            sh -c "$script --query"
            if [ $? -eq 0 ]; then
                FN=`basename "$script"`
                echo "${FN%.*}"
            fi
        done

        exit 0 ;;
    "--details" )
        if [ "$2" == "" ]; then
            echo "No suitable quickie escript name has been provided to query details for."
            exit 1    
        fi

        sh -c "$QUICKIES_DIR/$2.sh --details"
        if [ $? -ne 0 ]; then
            echo "Failed to obtain details for the given quickie script."
            exit 1
        fi
        exit 0 ;;
    "--execute" )
        if [ "$2" == "" ]; then
            echo "No suitable quickie script name has been provided for execution."
            exit 1    
        fi

        sh -c "$QUICKIES_DIR/$2.sh"
        exit $? ;;
esac


echo "Invalid command: $1"
exit 1
