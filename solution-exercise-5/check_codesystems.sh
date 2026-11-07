#!/bin/bash

# check_codesystems.sh - Prüft je Codesystem einen Code aus Blaze am Terminologieserver
# Usage: ./check_codesystems.sh [Terminologieserver-URL]
#   Übung 5: ./check_codesystems.sh https://tx.fhir.org/r4   (Standard)
#   Übung 6: ./check_codesystems.sh http://localhost:8081/fhir   (eigener FHIRsmith)
#            ./check_codesystems.sh http://localhost:8083/fhir   (MII Ontoserver über den Proxy)
# Ausgabe je Zeile: Ergebnis (true/false), Codesystem, geprüfter Code

TX="${1:-https://tx.fhir.org/r4}"
BLAZE="${BLAZE:-http://localhost:8080/fhir}"
CODES="codes.txt"

echo "Terminologieserver: $TX"
echo "FHIR-Server:        $BLAZE"
echo

# 1. Je Codesystem einen Code aus Blaze sammeln (wie in Übung 5, Schritt 5)
for type in Condition Procedure Observation Encounter; do
  curl -s "$BLAZE/$type?_count=4000" \
    | jq -r '[.entry[].resource | .. | objects | select(has("system") and has("code"))]
             | group_by(.system) | .[] | "\(.[0].system) \(.[0].code)"'
done | sort -u > "$CODES"

# 2. Jeden Code am Terminologieserver prüfen
while read -r system code; do
  result=$(curl -s -G "$TX/CodeSystem/\$validate-code" \
    --data-urlencode "url=$system" \
    --data-urlencode "code=$code" \
    | jq -r '.parameter[] | select(.name=="result") | .valueBoolean')
  echo -e "$result\t$system\t$code"
done < "$CODES"
