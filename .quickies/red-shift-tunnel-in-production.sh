#!/bin/sh

case "$1" in
    "--query" )
        if [ "$AWS_REDSHIFT_PORT" != "" ] && [ "$AWS_REDSHIFT_TUNNEL_HOST" != "" ] && [ "$AWS_REDSHIFT_PROD" != "" ]; then
            exit 0
        else 
            exit 1
        fi
        ;;
    "--details" )
        echo "This script opens an SSH tunnel to Redshift for '$AWS_REDSHIFT_PROD' (using '$AWS_REDSHIFT_TUNNEL_HOST:$AWS_REDSHIFT_PORT')."
        exit 0 ;;
esac    

echo "Starting the tunnel to '$AWS_REDSHIFT_PROD' using '$AWS_REDSHIFT_TUNNEL_HOST:$AWS_REDSHIFT_PORT'... CTRL-C to kill it!"
ssh -L $AWS_REDSHIFT_PORT:$AWS_REDSHIFT_TUNNEL_HOST:$AWS_REDSHIFT_PORT $AWS_REDSHIFT_PROD -N

