#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-csv-file>"
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

# Extract ONLY first column using cut, skip header
tail -n +2 "$CSV_FILE" | cut -d',' -f1 | while read -r domain; do
    
    # Skip empty lines
    [ -z "$domain" ] && continue
    
    echo "Scanning: $domain"
    
    # Try HTTPS
    result=$(httpx -silent -status-code -no-color "https://$domain" 2>/dev/null)
    
    if [ -n "$result" ]; then
        echo "✓ https://$domain" | tee -a "$OUTPUT_FILE"
    else
        # Try HTTP
        result=$(httpx -silent -status-code -no-color "http://$domain" 2>/dev/null)
        
        if [ -n "$result" ]; then
            echo "✓ http://$domain" | tee -a "$OUTPUT_FILE"
        else
            echo "✗ $domain [UNREACHABLE]" | tee -a "$OUTPUT_FILE"
        fi
    fi
done

echo ""
echo "Scan complete! Results saved to $OUTPUT_FILE"
