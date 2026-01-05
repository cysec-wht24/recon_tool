#!/bin/bash

# Check if httpx is installed
if ! command -v httpx &> /dev/null; then
    echo "Error: httpx is not installed!"
    echo "Install with: go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
    exit 1
fi

# Check for input file
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

# Output files
DOMAINS_TXT="domains_temp.txt"
OUTPUT_FILE="scan_results.txt"
DETAILED_OUTPUT="detailed_results.txt"

echo "==================================="
echo "  Domain Vulnerability Scanner"
echo "==================================="
echo ""
echo "Extracting domains from: $CSV_FILE"

# Extract domains properly - skip header, get first column, filter URL types
tail -n +2 "$CSV_FILE" | cut -d',' -f1 | tr -d '"' | grep -v '^$' > "$DOMAINS_TXT"

TOTAL_DOMAINS=$(wc -l < "$DOMAINS_TXT")
echo "Found $TOTAL_DOMAINS domains to scan"
echo ""

# Run httpx efficiently (single pass, checks both http and https)
echo "Starting scan... (this may take a while)"
echo ""

httpx -l "$DOMAINS_TXT" \
    -status-code \
    -title \
    -tech-detect \
    -content-length \
    -follow-redirects \
    -threads 50 \
    -timeout 10 \
    -retries 2 \
    -no-color \
    -silent \
    -o "$DETAILED_OUTPUT"

# Create summary report
echo "Domain Scan Results" > "$OUTPUT_FILE"
echo "===================" >> "$OUTPUT_FILE"
echo "Scan Date: $(date)" >> "$OUTPUT_FILE"
echo "Total Domains: $TOTAL_DOMAINS" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

if [ -f "$DETAILED_OUTPUT" ]; then
    ACTIVE_COUNT=$(wc -l < "$DETAILED_OUTPUT")
    INACTIVE_COUNT=$((TOTAL_DOMAINS - ACTIVE_COUNT))
    
    echo "Active Domains: $ACTIVE_COUNT" >> "$OUTPUT_FILE"
    echo "Inactive Domains: $INACTIVE_COUNT" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "Active Domains List:" >> "$OUTPUT_FILE"
    echo "-------------------" >> "$OUTPUT_FILE"
    
    # Parse and format results
    while IFS= read -r line; do
        url=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | grep -oP '\[\d+\]' | tr -d '[]')
        
        if [ -n "$status" ]; then
            echo "✓ $url [Status: $status]" | tee -a "$OUTPUT_FILE"
        else
            echo "✓ $url" | tee -a "$OUTPUT_FILE"
        fi
    done < "$DETAILED_OUTPUT"
    
    echo "" >> "$OUTPUT_FILE"
    echo "Inactive/Unreachable Domains:" >> "$OUTPUT_FILE"
    echo "----------------------------" >> "$OUTPUT_FILE"
    
    # Find inactive domains
    while IFS= read -r domain; do
        if ! grep -q "$domain" "$DETAILED_OUTPUT"; then
            echo "✗ $domain [UNREACHABLE]" | tee -a "$OUTPUT_FILE"
        fi
    done < "$DOMAINS_TXT"
else
    echo "No active domains found!" >> "$OUTPUT_FILE"
fi

echo ""
echo "==================================="
echo "Scan Complete!"
echo "==================================="
echo "Summary:"
echo "  Total Domains: $TOTAL_DOMAINS"
[ -f "$DETAILED_OUTPUT" ] && echo "  Active: $ACTIVE_COUNT" || echo "  Active: 0"
[ -f "$DETAILED_OUTPUT" ] && echo "  Inactive: $INACTIVE_COUNT" || echo "  Inactive: $TOTAL_DOMAINS"
echo ""
echo "Results saved to:"
echo "  - $OUTPUT_FILE (summary)"
echo "  - $DETAILED_OUTPUT (detailed httpx output)"
echo ""

# Cleanup
rm -f "$DOMAINS_TXT"
