#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-csv-file> [status-codes]"
    echo "Example: $0 /path/to/domains.csv 2xx"
    echo "Example: $0 /path/to/domains.csv 200,301,302"
    echo "Default: All status codes"
    exit 1
fi

CSV_FILE="$1"
STATUS_CODES="${2:-}"

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: File '$CSV_FILE' not found!"
    exit 1
fi

OUTPUT_FILE="scan_results.txt"
TEMP_FILE="temp_domains.txt"

echo "Starting scan of: $CSV_FILE"
if [ -n "$STATUS_CODES" ]; then
    echo "Filtering for status codes: $STATUS_CODES"
fi
echo ""

# Extract only first column (domains), skip header
tail -n +2 "$CSV_FILE" | cut -d',' -f1 | tr -d '"' > "$TEMP_FILE"

TOTAL=$(wc -l < "$TEMP_FILE")
echo "Found $TOTAL domains to scan"
echo ""

# Build httpx command
HTTPX_CMD="httpx -l $TEMP_FILE -silent -status-code -title -threads 30 -timeout 10"

# Add status code filter if provided
if [ -n "$STATUS_CODES" ]; then
    HTTPX_CMD="$HTTPX_CMD -mc $STATUS_CODES"
fi

HTTPX_CMD="$HTTPX_CMD -o $OUTPUT_FILE"

# Execute the command
eval $HTTPX_CMD

# Show results
if [ -f "$OUTPUT_FILE" ]; then
    ACTIVE=$(wc -l < "$OUTPUT_FILE")
    echo ""
    echo "Scan complete!"
    echo "Active: $ACTIVE/$TOTAL"
    echo "Results: $OUTPUT_FILE"
    echo ""
    cat "$OUTPUT_FILE"
else
    echo "No matching domains found"
fi

# Cleanup
rm -f "$TEMP_FILE"