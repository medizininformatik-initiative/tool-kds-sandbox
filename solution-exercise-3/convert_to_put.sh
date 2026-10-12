#!/bin/bash

# Skript: convert_to_put.sh
# Zweck: Wandelt alle POST-Requests in einem FHIR Bundle in PUT-Requests um und passt die URLs an.
# Usage: ./convert_to_put.sh <input-bundle.json> [output-bundle.json]

set -e

INPUT_FILE="$1"
OUTPUT_FILE="${2:-${INPUT_FILE%.json}_put.json}"

if [ -z "$INPUT_FILE" ]; then
    echo "Usage: $0 <input-bundle.json> [output-bundle.json]"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found."
    exit 1
fi

echo "Processing: $INPUT_FILE"

# Schritt: Ändere alle POST-Methoden in PUT und passe die URLs an
jq '
  .entry |= map(
    if .request.method == "POST" then
      .request.method = "PUT"
      | .request.url = (.resource.resourceType + "/" + .resource.id)
    else
      .
    end
  )
' "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Converted bundle saved to: $OUTPUT_FILE"
echo "Original entries: $(jq '.entry | length' "$INPUT_FILE")"
echo "New entries:      $(jq '.entry | length' "$OUTPUT_FILE")"
