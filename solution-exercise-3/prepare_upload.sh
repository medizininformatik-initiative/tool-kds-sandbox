#!/bin/bash

# prepare_upload.sh - Prepares a cleaned FHIR bundle for upload
# Converts searchset bundles to transaction and adds request objects if missing
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

# Output is NOT upload-ready yet: convert_to_put.sh (POST -> PUT) still has to
# run afterwards. Name it "_prepared" to avoid implying it is final.
OUTPUT_FILE="${INPUT_FILE%.json}_prepared.json"

echo "Preparing: $INPUT_FILE"

# Check bundle type
bundle_type=$(jq -r '.type' "$INPUT_FILE")

# Deduplicate resource IDs and add POST request objects to all entries.
# Some searchset bundles (e.g. UKW) contain distinct resources that share the
# same ID. When these are later converted to PUT (url = resourceType/id), the
# duplicates collide on the same URL and the server answers with HTTP 409
# Conflict. We therefore rename duplicate IDs by appending a suffix.
#
# We convert to a "transaction" bundle (not "batch"): the UKW/UKHD data contain
# circular references (Condition.encounter <-> Encounter.diagnosis[].condition).
# In a "batch" the server checks referential integrity per entry immediately, so
# a Condition referencing an Encounter that is not yet stored fails with HTTP 409
# ("Referential integrity violated"). In a "transaction" the server resolves
# references inside the bundle and stores everything atomically, so circular
# references work.
DEDUP_JQ='
    .type = "transaction" |
    .entry = (
        [.entry[] | select(.resource != null)] as $entries |
        reduce range(0; $entries|length) as $i (
            {seen: {}, out: []};
            $entries[$i] as $e |
            ($e.resource.resourceType + "/" + $e.resource.id) as $key |
            if .seen[$key] then
                .seen[$key] += 1 |
                ($e.resource.id + "-dup" + (.seen[$key]|tostring)) as $newid |
                .out += [{resource: ($e.resource | .id = $newid), request: {method: "POST", url: $e.resource.resourceType}}]
            else
                .seen[$key] = 1 |
                .out += [{resource: $e.resource, request: {method: "POST", url: $e.resource.resourceType}}]
            end
        ) | .out
    )
'

if [ "$bundle_type" = "searchset" ]; then
    echo "  Bundle type is 'searchset'. Converting to 'transaction'..."
    echo "  Adding request objects to all entries..."
    echo "  Renaming duplicate resource IDs (if any)..."

    jq "$DEDUP_JQ" "$INPUT_FILE" > "$OUTPUT_FILE"
else
    echo "  Bundle type is '$bundle_type'. Checking for request objects..."
    
    # Check if any entry has a request object
    has_request=$(jq '[.entry[].request] | any(. != null)' "$INPUT_FILE")
    
    if [ "$has_request" = "true" ]; then
        echo "  Request objects found. Copying bundle as-is..."
        cp "$INPUT_FILE" "$OUTPUT_FILE"
    else
        echo "  Adding request objects to all entries..."
        echo "  Renaming duplicate resource IDs (if any)..."
        jq "$DEDUP_JQ" "$INPUT_FILE" > "$OUTPUT_FILE"
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