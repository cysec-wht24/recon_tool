#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 assets.csv"
    exit 1
fi

CSV_FILE="$1"
OUTPUT_FILE="scan_results.txt"

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: File not found!"
    exit 1
fi

echo "Domain Scan Results" > "$OUTPUT_FILE"
echo "===================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "[*] Extracting domains..."

# Extract first column, skip header, trim spaces
awk -F',' 'NR>1 {print $1}' "$CSV_FILE" | sed 's/^ *//;s/ *$//' > domains.txt

echo "[*] Scanning live domains..."

# httpx handles http/https automatically
httpx -l domains.txt -silent -status-code -title \
| tee -a "$OUTPUT_FILE"

echo ""
echo "[+] Scan complete → $OUTPUT_FILE"
