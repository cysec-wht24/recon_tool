#!/bin/bash
set -euo pipefail

INPUT=$1
TODAY=$(date +%Y-%m-%d)

PATH_TO_SUBFINDER="$(command -v subfinder)"
PATH_TO_HTTPX="$(command -v httpx)"

PATH_TO_STORE="$PWD"

echo "This scan was created on $TODAY"

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <url | targets.txt | targets.csv>"
    exit 1
fi

echo "[+] Checking required binaries"
missing=0

for tool in "$PATH_TO_SUBFINDER" "$PATH_TO_HTTPX"; do
    if [ ! -x "$tool" ]; then
        echo "Missing or non-executable: $tool"
        missing=1
    fi
done

[ "$missing" -eq 1 ] && exit 1
echo "[+] All required tools found"

RAW_LIST=$(mktemp)
trap 'rm -f "$RAW_LIST"' EXIT

# Input handling
if [[ "$INPUT" =~ ^https?:// ]]; then
    echo "$INPUT" > "$RAW_LIST"
    RUN_NAME=$(echo "$INPUT" | sed 's~https\?://~~' | cut -d/ -f1 | tr '.' '_')
elif [[ "$INPUT" == *.txt ]]; then
    cp "$INPUT" "$RAW_LIST"
    RUN_NAME=$(basename "$INPUT" .txt)
elif [[ "$INPUT" == *.csv ]]; then
    cut -d, -f1 "$INPUT" | sed '1d' > "$RAW_LIST"
    RUN_NAME=$(basename "$INPUT" .csv)
else
    echo "Unsupported input format"
    exit 1
fi

# Setup output dirs
RUN_DIR="$PATH_TO_STORE/$RUN_NAME/$TODAY"
mkdir -p "$RUN_DIR/subdomains" "$RUN_DIR/alive"

MASTER="$RUN_DIR/master_targets.txt"
> "$MASTER"

while IFS= read -r LINE || [ -n "$LINE" ]; do
    LINE=$(echo "$LINE" | xargs)
    [ -z "$LINE" ] && continue

    if [[ "$LINE" == \*\.* ]]; then
        # Wildcard — strip *. and run subfinder
        DOMAIN="${LINE#\*.}"
        echo "[+] Enumerating subdomains: $DOMAIN"
        SUB_OUT="$RUN_DIR/subdomains/$DOMAIN.txt"
        "$PATH_TO_SUBFINDER" -d "$DOMAIN" -silent -o "$SUB_OUT" || true

        if [ -s "$SUB_OUT" ]; then
            echo "[+] Probing alive subdomains: $DOMAIN"
            ALIVE_OUT="$RUN_DIR/alive/$DOMAIN.txt"
            "$PATH_TO_HTTPX" -list "$SUB_OUT" -silent -o "$ALIVE_OUT" || true
            [ -s "$ALIVE_OUT" ] && cat "$ALIVE_OUT" >> "$MASTER" || true
        else
            echo "[-] No subdomains found for $DOMAIN"
        fi

    elif [[ "$LINE" =~ ^https?:// ]]; then
        # Direct URL — probe and add directly
        echo "[+] Probing direct URL: $LINE"
        ALIVE=$(echo "$LINE" | "$PATH_TO_HTTPX" -silent) || true
        [ -n "$ALIVE" ] && echo "$ALIVE" >> "$MASTER" || true

    else
        echo "[-] Skipping unrecognized entry: $LINE"
    fi

done < "$RAW_LIST"

sort -u "$MASTER" -o "$MASTER"

echo ""
echo "[+] Done. $(wc -l < "$MASTER") live targets saved to $MASTER"
echo "[+] Feed this into priorityscope.sh:"
echo "    ./priorityscope.sh $MASTER"