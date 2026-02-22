#!/bin/bash
set -euo pipefail

INPUT=$1
TODAY=$(date +%Y-%m-%d)

PATH_TO_KATANA="$HOME/go/bin/katana"
PATH_TO_NUCLEI="$HOME/go/bin/nuclei"
PATH_TO_ARJUN="$HOME/python/bin/arjun"
PATH_TO_FFUF="$HOME/go/bin/ffuf"
PATH_TO_STORE="$HOME/results"
PATH_TO_JQ="$(which jq)"
WORDLIST="/usr/share/seclists/Discovery/Web-Content/DirBuster-2007_directory-list-2.3-medium.txt"

echo "This scan was created on $TODAY"

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <url | targets.txt | targets.csv>"
    exit 1
fi

if [ ! -f "$WORDLIST" ]; then
    echo "Wordlist not found!"
    exit 1
fi

echo "[+] Checking required binaries"
missing=0

for tool in "$PATH_TO_KATANA" "$PATH_TO_NUCLEI" "$PATH_TO_ARJUN" "$PATH_TO_FFUF" "$PATH_TO_JQ"; do
    if [ ! -x "$tool" ]; then
        echo "Missing or non-executable: $tool"
        missing=1
    fi
done

[ "$missing" -eq 1 ] && exit 1
echo "[+] All required tools found"

URL_LIST=$(mktemp)
trap 'rm -f "$URL_LIST"' EXIT

# Input handling
if [[ "$INPUT" =~ ^https?:// ]]; then
    echo "$INPUT" > "$URL_LIST"
    RUN_NAME=$(echo "$INPUT" | sed 's~https\?://~~' | cut -d/ -f1 | tr '.' '_')
elif [[ "$INPUT" == *.txt ]]; then
    cp "$INPUT" "$URL_LIST"
    RUN_NAME=$(basename "$INPUT" | cut -d. -f1)
elif [[ "$INPUT" == *.csv ]]; then
    cut -d, -f1 "$INPUT" | sed '1d' > "$URL_LIST"
    RUN_NAME=$(basename "$INPUT" | cut -d. -f1)
else
    echo "Unsupported input format"
    exit 1
fi

echo "[+] Updating Nuclei templates"

if ! "$PATH_TO_NUCLEI" -update-templates >/dev/null 2>&1; then
    echo "[-] Nuclei template update failed"
    exit 1
fi

RUN_DIR="$PATH_TO_STORE/$RUN_NAME"
mkdir -p "$RUN_DIR" || {
    echo "Cannot create $RUN_DIR"
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

    echo "[+] Target: $URL"

    echo "[+] Running Katana (headless)"
    KATANA_OUT="$OUTPUT_DIR/katana_raw_$TODAY.txt"

    "$PATH_TO_KATANA" -u "$URL" \
        -headless \
        -jc \
        -kf all \
        -ef woff,css,png,jpg,gif,svg,ttf,woff2,ico,eot \
        -d 3 \
        -xhr \
        -timeout 30 \
        -retry 2 \
        -rate-limit 50 \
        -silent \
        </dev/null \
        > "$KATANA_OUT"
    
    if [ ! -s "$KATANA_OUT" ]; then
        echo "[-] Katana produced no results, skipping target"
        continue
    fi

    echo "[+] Cleaning URLs"
    CLEAN_URLS="$OUTPUT_DIR/urls_clean_$TODAY.txt"

    # can add pdf
    sort -u "$KATANA_OUT" \
    | grep -Evi "\.(woff|css|png|jpg|gif|svg|ttf|woff2|ico|eot|mp4|mp3)(\?|$)" \
    > "$CLEAN_URLS"

    JS_FILES="$OUTPUT_DIR/js_files_$TODAY.txt"
    grep -Ei "\.js(\?|$)" "$CLEAN_URLS" > "$JS_FILES"
    echo "[+] Extracted JS files"

    PARAM_URLS="$OUTPUT_DIR/param_urls_$TODAY.txt"
    grep -E "\?|=" "$CLEAN_URLS" > "$PARAM_URLS"

    echo "[+] Running FFUF (directory fuzz)"
    FFUF_JSON="$OUTPUT_DIR/ffuf_dirs_$TODAY.json"

    "$PATH_TO_FFUF" \
        -u "$URL/FUZZ" \
        -w "$WORDLIST" \
        -t 50 \
        -rate 80 \
        -mc all \
        -fc 404 \
        -recursion \
        -recursion-depth 2 \
        -recursion-strategy default \
        -s \
        -of json \
        -o "$FFUF_JSON"

    # -------------------------------
    # Extract URLs from FFUF results
    # -------------------------------
    FFUF_URLS="$OUTPUT_DIR/ffuf_urls_$TODAY.txt"

    if [ -s "$FFUF_JSON" ]; then
        jq -r '.results[]?.url' "$FFUF_JSON" 2>/dev/null \
        | sort -u > "$FFUF_URLS"
    else
        touch "$FFUF_URLS"
    fi

    ARJUN_JSON="$OUTPUT_DIR/arjun_$TODAY.json"
    ARJUN_URLS="$OUTPUT_DIR/arjun_urls_$TODAY.txt"

    if [ -s "$PARAM_URLS" ]; then
        echo "[+] Running Arjun"
        "$PATH_TO_ARJUN" -i "$PARAM_URLS" \
        -o "$ARJUN_JSON"
        # Extract discovered URLs from Arjun JSON output
        if [ -s "$ARJUN_JSON" ]; then
            jq -r 'to_entries[] | .key as $url | .value.params[]? | $url + "?" + .' "$ARJUN_JSON" 2>/dev/null \
            | sort -u > "$ARJUN_URLS"
        else
            touch "$ARJUN_URLS"
        fi
    else
        echo "[-] No parameter URLs found for Arjun"
        touch "$ARJUN_URLS"
    fi

    # -------------------------------
    # Merge ALL discovered URLs
    # -------------------------------
    ALL_URLS="$OUTPUT_DIR/all_urls_$TODAY.txt"

    cat "$CLEAN_URLS" "$FFUF_URLS" "$ARJUN_URLS" 2>/dev/null \
    | sort -u > "$ALL_URLS"

    if [ -s "$ALL_URLS" ]; then
        echo "[+] Running Nuclei"
        "$PATH_TO_NUCLEI" \
            -l "$ALL_URLS" \
            -tags cve,rce,sqli,xss,ssrf,lfi,redirect,exposure,takeover,api,graphql,jwt,cors \
            -severity low,medium,high,critical \
            -etags tech,dos,fuzz \
            -rl 50 \
            -c 50 \
            -timeout 10 \
            -retries 2 \
            -o "$OUTPUT_DIR/nuclei_$TODAY.json" \
            -json
    else
        echo "[-] No URLs for Nuclei"
    fi

    echo "[+] Output saved to $OUTPUT_DIR"
    echo ""

done < "$URL_LIST"

echo "[+] All scans completed"
