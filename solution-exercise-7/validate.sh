#!/bin/bash

# validate.sh - Validiert eine FHIR-Ressource mit dem MII FHIR Validator
# Usage: ./validate.sh <ressource.json>
# Exit-Code: 0 = keine Fehler, 1 = Fehler gefunden, 2 = Aufruf fehlgeschlagen

FILE="$1"
VALIDATOR_URL="${VALIDATOR_URL:-http://localhost:8082}"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "Usage: $0 <ressource.json>"
    exit 2
fi

RESULT=$(curl -s -X POST "$VALIDATOR_URL/validateResource" \
    -H "Content-Type: application/fhir+json" \
    --data @"$FILE")

if [ "$(echo "$RESULT" | jq -r '.resourceType' 2>/dev/null)" != "OperationOutcome" ]; then
    echo "❌ Keine gültige Antwort vom Validator unter $VALIDATOR_URL"
    exit 2
fi

ERRORS=$(echo "$RESULT" | jq '[.issue[] | select(.severity == "error" or .severity == "fatal")] | length')
WARNINGS=$(echo "$RESULT" | jq '[.issue[] | select(.severity == "warning")] | length')

if [ "$ERRORS" -gt 0 ]; then
    echo "❌ $FILE: $ERRORS Fehler, $WARNINGS Warnungen"
    echo "$RESULT" | jq '[.issue[] | select(.severity == "error" or .severity == "fatal") | {code, text: (.details.text // .diagnostics), ort: (.expression // .location)[0]}]'
    exit 1
else
    echo "✅ $FILE: 0 Fehler, $WARNINGS Warnungen"
    exit 0
fi
