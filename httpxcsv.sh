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

# Extract only the first column (identifier) and second column (asset_type)
tail -n +2 "$CSV_FILE" | while IFS=',' read -r identifier asset_type _; do
    # Remove any quotes from the identifier
    domain=$(echo "$identifier" | tr -d '"' | tr -d ' ')
    asset=$(echo "$asset_type" | tr -d '"' | tr -d ' ')
    
    # Only process if asset_type is URL
    if [[ "$asset" == "URL" ]]; then
        echo "Scanning: $domain"
        
        # Try HTTPS first
        status_https=$(httpx -silent -status-code -no-color "https://$domain" 2>/dev/null | head -n1)
        
        if [ -n "$status_https" ]; then
            status_code=$(echo "$status_https" | grep -oP '\[\K[0-9]+(?=\])')
            echo "✓ https://$domain [Status: $status_code]" | tee -a "$OUTPUT_FILE"
        else
            # Try HTTP if HTTPS fails
            status_http=$(httpx -silent -status-code -no-color "http://$domain" 2>/dev/null | head -n1)
            
            if [ -n "$status_http" ]; then
                status_code=$(echo "$status_http" | grep -oP '\[\K[0-9]+(?=\])')
                echo "✓ http://$domain [Status: $status_code]" | tee -a "$OUTPUT_FILE"
            else
                echo "✗ $domain [UNREACHABLE]" | tee -a "$OUTPUT_FILE"
            fi
        fi
    fi
done

echo ""
echo "Scan complete! Results saved to $OUTPUT_FILE"
