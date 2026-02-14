#!/bin/bash
INPUT=$1
TODAY=$(date +%Y-%m-%d)
PATH_TO_KATANA="$HOME/go/bin/katana"
PATH_TO_NUCLEI="$HOME/go/bin/nuclei"
PATH_TO_ARJUN="$HOME/python/bin/arjun"
PATH_TO_STORE="$HOME/results"

echo "This scan was created on $TODAY"
if [ -z "$INPUT" ]; then
    echo "Usage: $0 <url | targets.txt | targets.csv>"
    exit 1
fi

echo "checking required binaries"
missing=0

for tool in "$PATH_TO_KATANA" "$PATH_TO_NUCLEI" "$PATH_TO_ARJUN"; do
    if [ ! -x "$tool" ]; then
        echo "Missing or non-executable: $tool"
        missing=1
    fi
done

[ "$missing" -eq 1 ] && exit 1
echo "Katana, arjun, nuclei tool present"

URL_LIST=$(mktemp)
trap 'rm -f "$URL_LIST"' EXIT

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
mkdir -p "$RUN_DIR" || {
    echo "Cannot create $RUN_DIR (permission denied?)"
    exit 1
}


while IFS= read -r URL || [ -n "$URL" ]; do
    URL=$(echo "$URL" | xargs)
    [ -z "$URL" ] && continue

    if [[ ! "$URL" =~ ^https?:// ]]; then
        URL="https://$URL"
    fi

    DIR_NAME=$(echo "$URL" | sed 's~https\?://~~' | tr '/' '_')
    OUTPUT_DIR="$RUN_DIR/$DIR_NAME"
    mkdir -p "$OUTPUT_DIR"

    echo "executing arjun"

    echo "Output saved to $OUTPUT_DIR"

done < "$URL_LIST"
echo "[+] All crawls and wayback completed"