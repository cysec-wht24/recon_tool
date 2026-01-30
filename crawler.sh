#!/bin/bash
TODAY=$(date +%Y-%m-%d)
echo "This scan was created on $TODAY"

echo "checking directory exists"
PATH_TO_KATANA="whatever/path/katana"
if [ ! -x "$PATH_TO_KATANA" ]; then
    echo "Katana tool not available"
    exit 1
fi

DOMAIN=$1
PATH_TO_STORE="/home/results/$DOMAIN"
if [ ! -d "$PATH_TO_STORE" ]; then
    echo "path to store does not exist, creating it..."
    mkdir -p "$PATH_TO_STORE"
fi

echo "Running standard mode scan"
katana $DOMAIN > "$PATH_TO_STORE/katana_standard_$TODAY.txt"
echo "Output stored successfully"
