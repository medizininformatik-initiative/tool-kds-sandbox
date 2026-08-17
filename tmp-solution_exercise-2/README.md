# Lösung Exercise 2 – KDS-Beispieldaten in FHIR-Server laden

## Enthaltene Dateien

| Datei | Zweck |
|---|---|
| `repair-bundle.sh` | Hilfsskript, das fehlende Ressourcen in einem Transaction-Bundle ergänzt (für referenzielle Integrität) |

## Verwendung

```bash
# 1. Musterdatenspende klonen
git clone https://github.com/medizininformatik-initiative/musterdatenspende-diz.git
cd musterdatenspende-diz

# 2. Ein DIZ-Flavour entpacken (z. B. UKSH)
unzip UKSH/UKSH-2025-11-11.zip

# 3. Transaction-Bundle bauen
bash bin/merge-bundles.sh UKSH-2025-11-11/*.json > transaction-bundle.json

# 4. Fehlende Referenzen prüfen (optional)
bash bin/unresolved-references.sh transaction-bundle.json

# 5. Bundle reparieren (fehlende Locations/Encounters ergänzen)
bash ../tmp-solution_exercise-2/repair-bundle.sh transaction-bundle.json > bundle-repaired.json

# 6. In Blaze hochladen
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @bundle-repaired.json
```
