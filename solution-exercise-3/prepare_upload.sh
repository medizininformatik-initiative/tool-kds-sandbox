#!/bin/bash

# prepare_upload.sh - Prepares a cleaned FHIR bundle for upload
# Converts searchset bundles to batch and adds request objects if missing
# Usage: ./prepare_upload.sh <cleaned-bundle-file.json>

set -e

INPUT_FILE="$1"

if [ -z "$INPUT_FILE" ]; then
    echo "Usage: $0 <cleaned-bundle-file.json>"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

OUTPUT_FILE="${INPUT_FILE%.json}_upload_ready.json"

echo "Preparing: $INPUT_FILE"

# Check bundle type
bundle_type=$(jq -r '.type' "$INPUT_FILE")

if [ "$bundle_type" = "searchset" ]; then
    echo "  Bundle type is 'searchset'. Converting to 'batch'..."
    echo "  Adding request objects to all entries..."
    
    jq '
        .type = "batch" |
        .entry = [.entry[] | 
            select(.resource != null) |
            {
                resource: .resource,
                request: {
                    method: "POST",
                    url: .resource.resourceType
                }
            }
        ]
    ' "$INPUT_FILE" > "$OUTPUT_FILE"
else
    echo "  Bundle type is '$bundle_type'. Checking for request objects..."
    
    # Check if any entry has a request object
    has_request=$(jq '[.entry[].request] | any(. != null)' "$INPUT_FILE")
    
    if [ "$has_request" = "true" ]; then
        echo "  Request objects found. Copying bundle as-is..."
        cp "$INPUT_FILE" "$OUTPUT_FILE"
    else
        echo "  Adding request objects to all entries..."
        jq '
            .entry = [.entry[] | 
                select(.resource != null) |
                {
                    resource: .resource,
                    request: {
                        method: "POST",
                        url: .resource.resourceType
                    }
                }
            ]
        ' "$INPUT_FILE" > "$OUTPUT_FILE"
    fi
fi

echo ""
echo "==================================="
echo "Preparation complete!"
echo "==================================="
echo "Output file: $OUTPUT_FILE"
echo "Bundle type: $(jq -r '.type' "$OUTPUT_FILE")"
echo "Total entries: $(jq '.entry | length' "$OUTPUT_FILE")"
echo "==================================="