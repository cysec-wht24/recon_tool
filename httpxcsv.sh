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
TEMP_FILE="temp_domains.txt"

echo "Starting scan of: $CSV_FILE"
echo ""

# Extract only first column (domains), skip header
tail -n +2 "$CSV_FILE" | cut -d',' -f1 | tr -d '"' > "$TEMP_FILE"

TOTAL=$(wc -l < "$TEMP_FILE")
echo "Found $TOTAL domains to scan"
echo ""

# Scan all domains with httpx (batch mode)
httpx -l "$TEMP_FILE" \
    -silent \
    -status-code \
    -title \
    -threads 30 \
    -timeout 10 \
    -o "$OUTPUT_FILE"

# Show results
if [ -f "$OUTPUT_FILE" ]; then
    ACTIVE=$(wc -l < "$OUTPUT_FILE")
    echo ""
    echo "Scan complete!"
    echo "Active: $ACTIVE/$TOTAL"
    echo "Results: $OUTPUT_FILE"
    echo ""
    sort -t'[' -k2 -n "$OUTPUT_FILE"
else
    echo "No active domains found"
fi

# Cleanup
rm -f "$TEMP_FILE"