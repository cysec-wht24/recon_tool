#!/bin/bash
INPUT=$1
TODAY=$(date +%Y-%m-%d)
PATH_TO_KATANA="whatever/path/katana"
PATH_TO_WAYBACKURL="whatever/path/wayback"
PATH_TO_STORE="/home/results"
echo "This scan was created on $TODAY"

echo "checking directory exists"
if [ ! -x "$PATH_TO_KATANA" ]; then
    echo "Katana binary not present"
    exit 1
fi

if [ ! -x "$PATH_TO_WAYBACKURL" ]; then
    echo "waybackurls binary not present"
    exit 1
fi

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <url | targets.txt | targets.csv>"
    exit 1
fi

URL_LIST="/tmp/katana_input_urls_$TODAY.txt"
if [[ "$INPUT" =~ ^https?:// ]]; then
    echo "[+] Single URL detected"
    echo "$INPUT" > "$URL_LIST"
elif [[ "$INPUT" == *.txt ]]; then
    echo "[+] TXT file detected"
    cp "$INPUT" "$URL_LIST"
elif [[ "$INPUT" == *.csv ]]; then
    echo "[+] CSV file detected"
    cut -d, -f1 "$INPUT" | sed '1d' > "$URL_LIST"
else
    echo "Unsupported input format"
    exit 1
fi

RUN_NAME=$(basename "$INPUT" | cut -d. -f1)
RUN_DIR="$PATH_TO_STORE/$RUN_NAME"
mkdir -p "$RUN_DIR"

while read -r URL; do
    [ -z "$URL" ] && continue

    if [[ ! "$URL" =~ ^https?:// ]]; then
        URL="https://$URL"
    fi

    DIR_NAME=$(echo "$URL" | sed 's~https\?://~~' | tr '/' '_')
    OUTPUT_DIR="$RUN_DIR/$DIR_NAME"
    mkdir -p "$OUTPUT_DIR"

    echo "[+] standard crawl on $URL"
    "$PATH_TO_KATANA" -u "$URL" \
        -depth 3 \
        -jc \
        -kf all \
        -iqp \
        -rl 100 \
        -silent \
        > "$OUTPUT_DIR/katana_standard_$TODAY.txt"

    echo "[+] Waybackurls on $URL"
    HOST=$(echo "$URL" | sed 's~https\?://~~' | cut -d/ -f1)
    "$PATH_TO_WAYBACKURL" "$HOST" > "$OUTPUT_DIR/wayback_$TODAY.txt"

    echo "Output saved to $OUTPUT_DIR"

done < "$URL_LIST"
echo "[+] All crawls and wayback completed"