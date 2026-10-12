#!/bin/bash

# clean_bundle.sh - Removes resources with unresolved references from a FHIR bundle
# Usage: ./clean_bundle.sh <bundle-file.json>

set -e

INPUT_FILE="$1"

if [ -z "$INPUT_FILE" ]; then
    echo "Usage: $0 <bundle-file.json>"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

OUTPUT_FILE="${INPUT_FILE%.json}_cleaned.json"
TEMP_FILE="/tmp/bundle_clean_temp_$$.json"
cp "$INPUT_FILE" "$TEMP_FILE"

echo "Processing: $INPUT_FILE"
echo "Initial entries: $(jq '.entry | length' "$TEMP_FILE")"

iteration=0
total_removed=0

while true; do
    iteration=$((iteration + 1))
    echo "  Iteration $iteration..."
    
    current_count=$(jq '.entry | length' "$TEMP_FILE")
    
    # Get all resource IDs and save to temp file
    jq '[.entry[] | .resource.resourceType + "/" + .resource.id] | unique' "$TEMP_FILE" > /tmp/ids_$$.json
    
    # Get all references and save to temp file
    jq '[.entry[] | .resource | .. | objects | .reference? | select(. != null)] | unique' "$TEMP_FILE" > /tmp/refs_$$.json
    
    # Find unresolved references: refs - ids
    jq -n --slurpfile ids /tmp/ids_$$.json --slurpfile refs /tmp/refs_$$.json '$refs[0] - $ids[0]' > /tmp/unresolved_$$.json
    
    unresolved_count=$(jq 'length' /tmp/unresolved_$$.json)
    
    if [ "$unresolved_count" -eq 0 ]; then
        echo "  No more unresolved references."
        rm -f /tmp/ids_$$.json /tmp/refs_$$.json /tmp/unresolved_$$.json
        break
    fi
    
    echo "  Found $unresolved_count unresolved references"
    
    # Filter: remove any entry that has a reference to an unresolved ID
    # We do this by checking for each entry if it has any "bad" reference
    jq --slurpfile unresolved /tmp/unresolved_$$.json '
        .entry = [.entry[] | 
            select(
                [(.resource | .. | objects | .reference? // empty) | select(. != null)] as $refs |
                ($refs | map(select(. as $r | $unresolved[0] | index($r) != null)) | length) == 0
            )
        ]
    ' "$TEMP_FILE" > /tmp/cleaned_$$.json
    
    mv /tmp/cleaned_$$.json "$TEMP_FILE"
    
    new_count=$(jq '.entry | length' "$TEMP_FILE")
    removed=$((current_count - new_count))
    
    if [ "$removed" -eq 0 ]; then
        echo "  No more resources removed."
        break
    fi
    
    total_removed=$((total_removed + removed))
    echo "  Removed $removed resources (total removed so far: $total_removed)"
    
    rm -f /tmp/ids_$$.json /tmp/refs_$$.json /tmp/unresolved_$$.json
    
    # Break after a few iterations to prevent infinite loops (safety)
    if [ "$iteration" -gt 20 ]; then
        echo "  Warning: Reached maximum iterations (20). Stopping."
        break
    fi
done

# Final verification - run one more clean pass
jq '[.entry[] | .resource.resourceType + "/" + .resource.id] | unique' "$TEMP_FILE" > /tmp/final_ids_$$.json
jq '[.entry[] | .resource | .. | objects | .reference? | select(. != null)] | unique' "$TEMP_FILE" > /tmp/final_refs_$$.json
jq -n --slurpfile ids /tmp/final_ids_$$.json --slurpfile refs /tmp/final_refs_$$.json '$refs[0] - $ids[0]' > /tmp/final_unresolved_$$.json

if [ "$(jq 'length' /tmp/final_unresolved_$$.json)" -gt 0 ]; then
    echo "  Warning: Some unresolved references remain after final pass."
fi
rm -f /tmp/final_ids_$$.json /tmp/final_refs_$$.json /tmp/final_unresolved_$$.json

# Calculate statistics using temp files to avoid argument list too long
jq '[.entry[] | .resource.resourceType + "/" + .resource.id]' "$INPUT_FILE" > /tmp/orig_ids_$$.json
jq '[.entry[] | .resource.resourceType + "/" + .resource.id]' "$TEMP_FILE" > /tmp/cleaned_ids_$$.json

# Count removals by type - compute everything in jq
jq -n --slurpfile orig /tmp/orig_ids_$$.json --slurpfile clean /tmp/cleaned_ids_$$.json '
    ($orig[0] - $clean[0]) as $removed |
    {
        total_removed: ($removed | length),
        by_type: ($removed | map(split("/")[0]) | group_by(.) | map({type: .[0], count: length}))
    }
' > /tmp/stats_$$.json

orig_count=$(jq 'length' /tmp/orig_ids_$$.json)
clean_count=$(jq 'length' /tmp/cleaned_ids_$$.json)

echo ""
echo "==================================="
echo "Bundle cleaning summary"
echo "==================================="
echo "Original resources: $orig_count"
echo "Final resources: $clean_count"
echo "Total removed: $(jq '.total_removed' /tmp/stats_$$.json)"
echo ""
echo "Removed by resource type:"
removed_types=$(jq '.by_type' /tmp/stats_$$.json)
if [ "$(jq 'length' /tmp/stats_$$.json)" -eq 0 ]; then
    echo "  (none)"
else
    jq -r '.by_type[] | "  \(.type): \(.count)"' /tmp/stats_$$.json
fi
echo "==================================="

cp "$TEMP_FILE" "$OUTPUT_FILE"
rm -f "$TEMP_FILE" /tmp/orig_ids_$$.json /tmp/cleaned_ids_$$.json /tmp/stats_$$.json

echo ""
echo "Cleaned bundle saved to: $OUTPUT_FILE"