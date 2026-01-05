#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-csv-file>"
    echo "Example: $0 /path/to/domains.csv"
    exit 1
fi

CSV_FILE="$1"

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: File '$CSV_FILE' not found!"
    exit 1
fi

OUTPUT_FILE="scan_results.txt"

echo "Domain Scan Results" > "$OUTPUT_FILE"
echo "===================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Starting scan of: $CSV_FILE"
echo ""

tail -n +2 "$CSV_FILE" | while IFS=, read -r identifier asset_type rest; do
    if [[ "$asset_type" == "URL" ]]; then
        domain=$(echo "$identifier" | tr -d '"')
        
        echo "Scanning: $domain"
        
        if httpx "https://$domain" -silent -status-code > /dev/null 2>&1; then
            status=$(httpx "https://$domain" -silent -status-code 2>/dev/null)
            echo "✓ https://$domain [$status]" | tee -a "$OUTPUT_FILE"
        elif httpx "http://$domain" -silent -status-code > /dev/null 2>&1; then
            status=$(httpx "http://$domain" -silent -status-code 2>/dev/null)
            echo "✓ http://$domain [$status]" | tee -a "$OUTPUT_FILE"
        else
            echo "✗ $domain [UNREACHABLE]" | tee -a "$OUTPUT_FILE"
        fi
    fi
done

echo ""
echo "Scan complete! Results saved to $OUTPUT_FILE"