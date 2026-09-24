#!/usr/bin/env bash
# ============================================================
# repair-bundle.sh
#
# Ergänzt fehlende Ressourcen in einem FHIR Transaction-Bundle.
#
# Die Musterdatenspende-Daten sind nicht immer referenziell
# integer (siehe README des Repos). Dieses Skript identifiziert
# Referenzen, die im Bundle nicht aufgelöst werden können, und
# generiert minimale Dummy-Ressourcen (Location, Encounter, Patient, und andere),
# damit der Import in Blaze (oder einen anderen FHIR-Server mit
# referenzieller Integrität) funktioniert.
#
# Usage:
#   bash repair-bundle.sh transaction-bundle.json > bundle-repaired.json
#
# Requires: jq (https://jqlang.org/)
# ============================================================

set -euo pipefail

BUNDLE="${1:?Fehler: Bitte ein Transaction-Bundle als Argument angeben.

Usage: bash repair-bundle.sh input-bundle.json > output-bundle-repaired.json}"

if ! command -v jq &>/dev/null; then
  echo "Fehler: jq ist nicht installiert."
  echo "Installiere es mit: sudo apt install jq -y" >&2
  exit 1
fi

# -----------------------------------------------------------
# Schritt 1: Alle vorhandenen Ressourcen-IDs sammeln
# -----------------------------------------------------------
EXISTING_IDS=$(jq -r '
  [.entry[] | .resource.resourceType + "/" + .resource.id]
  | unique[]
' "$BUNDLE")

# -----------------------------------------------------------
# Schritt 2: Alle Referenzen aus dem Bundle sammeln
# -----------------------------------------------------------
ALL_REFS=$(jq -r '
  [.entry[]
   | .resource
   | .. | objects | .reference?
   | select(. != null and . != "")]
  | unique[]
' "$BUNDLE")

# -----------------------------------------------------------
# Schritt 3: Fehlende Referenzen identifizieren (Differenz)
# -----------------------------------------------------------
BROKEN_REFS=$(comm -13 \
  <(echo "$EXISTING_IDS" | sort) \
  <(echo "$ALL_REFS" | sort) \
  | grep -v '^[[:space:]]*$' || true)

# -----------------------------------------------------------
# Schritt 3a: Fehlende Patienten automatisch erkennen
# -----------------------------------------------------------
# Prüfen, ob alle referenzierten Patienten auch im Bundle existieren
PATIENT_REFS=$(jq -r '
  [.entry[] | .resource | .. | objects | .reference?
   | select(. != null and . != "" and type == "string")
   | select(startswith("Patient/"))] | unique[]
' "$BUNDLE")

# Fehlende Patienten identifizieren
MISSING_PATIENTS=$(comm -13 \
  <(echo "$EXISTING_IDS" | grep '^Patient/' | sort) \
  <(echo "$PATIENT_REFS" | sort) \
  | grep -v '^[[:space:]]*$' || true)

# Fehlende Patienten zu BROKEN_REFS hinzufügen
if [[ -n "$MISSING_PATIENTS" ]]; then
  BROKEN_REFS=$(echo "$BROKEN_REFS" > /tmp/broken_refs.tmp && \
                echo "$MISSING_PATIENTS" >> /tmp/broken_refs.tmp && \
                sort /tmp/broken_refs.tmp | uniq && \
                rm /tmp/broken_refs.tmp)
fi

# -----------------------------------------------------------
# Schritt 3b: Patient für Encounter-Dummies hinzufügen
# -----------------------------------------------------------
# Encounter-Dummy-Ressourcen benötigen eine Subject-Referenz auf einen Patienten.
# Da die Encounter-Dummies auf Patient/dummy-patient-for-encounter verweisen,
# müssen wir diesen Patienten ebenfalls als Dummy erstellen, damit die
# referenzielle Integrität gewährleistet ist.
UUID_PATIENT="Patient/dummy-patient-for-encounter"
if ! echo "$EXISTING_IDS" | grep -qF "$UUID_PATIENT"; then
  BROKEN_REFS=$(echo "$BROKEN_REFS" > /tmp/broken_refs.tmp && \
                echo "$UUID_PATIENT" >> /tmp/broken_refs.tmp && \
                sort /tmp/broken_refs.tmp | uniq && \
                rm /tmp/broken_refs.tmp)
fi

# -----------------------------------------------------------
# Schritt 4: Dummy-Ressourcen generieren
# -----------------------------------------------------------
GENERATED=""
while IFS=/ read -r TYPE ID; do
  [[ -z "$TYPE" || -z "$ID" ]] && continue

  case "$TYPE" in
    Location)
      DUMPS=$(jq -n \
        --arg id "$ID" \
        --arg name "$ID" \
        '{
          resourceType: "Location",
          id: $id,
          name: $name,
          status: "active"
        }')
      ;;
    # Encounter-Dummy-Ressourcen benötigen eine Subject-Referenz auf einen Patienten.
    # Wir verwenden einen gemeinsamen Dummy-Patienten für alle fehlenden Encounters.
    Encounter)
      DUMPS=$(jq -n \
        --arg id "$ID" \
        '{
          resourceType: "Encounter",
          id: $id,
          status: "finished",
          "class": {
            "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
            "code": "AMB",
            "display": "ambulatory"
          },
          "subject": {
            "reference": "Patient/dummy-patient-for-encounter"
          }
        }')
      ;;
    Patient)
      # Dieser Patient wird benötigt, damit die Encounter-Dummies auf ihn referenzieren.
      # Er ist als "DUMMY-Patient-..." gekennzeichnet, um Verwechslungen mit echten
      # Patienten zu vermeiden.
      DUMPS=$(jq -n \
        --arg id "$ID" \
        '{
          resourceType: "Patient",
          id: $id,
          active: true,
          name: [{text: ("DUMMY-Patient-" + $id)}],
          identifier: [{
            system: "https://dummy.example.org/patient-id",
            value: $id
          }]
        }')
      ;;
    *)
      DUMPS=$(jq -n \
        --arg type "$TYPE" \
        --arg id "$ID" \
        '{
          resourceType: $type,
          id: $id
        }')
      ;;
  esac
  GENERATED="$GENERATED$DUMPS"$'\n'
done <<< "$BROKEN_REFS"

# -----------------------------------------------------------
# Schritt 5: Dummy-Ressourcen als Entry-Objekte verpacken
# -----------------------------------------------------------
NEW_ENTRIES=$(echo "$GENERATED" | jq -s '
  [.[] | select(. != null) | {
    resource: .,
    request: {
      method: "PUT",
      url: (.resourceType + "/" + .id)
    }
  }]
')

# -----------------------------------------------------------
# Schritt 6: POST → PUT umwandeln und Bundle reparieren
# -----------------------------------------------------------
# Zuerst alle POST-Requests zu PUT umwandeln, dann Dummy-Ressourcen hinzufügen
jq --argjson new_entries "$NEW_ENTRIES" '
  # POST → PUT umwandeln
  .entry |= map(
    if .request.method == "POST" then
      .request.method = "PUT"
      | .request.url = (.resource.resourceType + "/" + .resource.id)
    else
      .
    end
  )
  # Dummy-Ressourcen hinzufügen
  | .entry += $new_entries
  | .total = (.entry | length)
' "$BUNDLE"

# -----------------------------------------------------------
# Schritt 7: Statistik ausgeben (stderr)
# -----------------------------------------------------------
NUM_POST=$(jq '[.entry[] | select(.request.method == "POST")] | length' "$BUNDLE")
NUM_PUT=$(jq '[.entry[] | select(.request.method == "PUT")] | length' "$BUNDLE")
NUM_BROKEN=$(echo "$BROKEN_REFS" | grep -c '.' 2>/dev/null || echo 0)
NUM_GENERATED=$(echo "$GENERATED" | jq -s 'length' 2>/dev/null || echo 0)

echo "" >&2
echo "═══════════════════════════════════════════════════════════" >&2
echo " repair-bundle.sh – Ergebnis" >&2
echo "═══════════════════════════════════════════════════════════" >&2
echo " POST → PUT umgewandelt:      $NUM_POST" >&2
echo " Fehlende Referenzen:         $NUM_BROKEN" >&2
echo " Generierte Dummy-Ressourcen: $NUM_GENERATED" >&2
echo "═══════════════════════════════════════════════════════════" >&2
echo "" >&2