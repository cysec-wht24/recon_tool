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
        
        status_https=$(httpx "https://$domain" -silent -status-code 2>/dev/null)
        
        if [ -n "$status_https" ]; then
            echo "✓ https://$domain [$status_https]" | tee -a "$OUTPUT_FILE"
        else
            status_http=$(httpx "http://$domain" -silent -status-code 2>/dev/null)
            
            if [ -n "$status_http" ]; then
                echo "✓ http://$domain [$status_http]" | tee -a "$OUTPUT_FILE"
            else
                echo "✗ $domain [UNREACHABLE - No response]" | tee -a "$OUTPUT_FILE"
            fi
        fi
    fi
done

echo ""
echo "Scan complete! Results saved to $OUTPUT_FILE"