# Lösung Exercise 3 – KDS-Beispieldaten in FHIR-Server laden

## Enthaltene Dateien

| Datei | Zweck |
|---|---|
| `clean_bundle.sh` | **Hauptwerkzeug:** Entfernt Ressourcen mit fehlenden Referenzen (automatisierte Bereinigung) |
| `convert_to_put.sh` | **Hauptwerkzeug:** Wandelt POST → PUT um (damit fixe IDs erhalten bleiben) |
| `prepare_upload.sh` | **Optional:** Konvertiert `searchset` → `transaction`, fügt `request` Objekte hinzu und benennt doppelte IDs um |

## Verwendung (Empfohlener Workflow für Exercise 3)

### Hauptworkflow (UKSH - referenzielle Integrität):

```bash
# 1. Daten bereinigen
bash clean_bundle.sh /path/to/transaction-bundle.json
# → erzeugt: transaction-bundle_cleaned.json

# 2. POST → PUT umwandeln (damit fixe IDs erhalten bleiben)
bash convert_to_put.sh transaction-bundle_cleaned.json
# → erzeugt: transaction-bundle_cleaned_put.json

# 3. Upload (transaction bundle passt bereits)
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @transaction-bundle_cleaned_put.json
```

### Optional: Für UKW/UKHD (searchset bundles):

```bash
# 1. Daten bereinigen (wie oben)
bash clean_bundle.sh UKW/UKW-2025-12-05.json
# → erzeugt: UKW-2025-12-05_cleaned.json

# 2. Vorbereiten (searchset → transaction Konvertierung, optional)
bash prepare_upload.sh UKW/UKW-2025-12-05_cleaned.json
# → erzeugt: UKW-2025-12-05_prepared.json

# 3. POST → PUT umwandeln (erst jetzt ist das Bundle upload-bereit)
bash convert_to_put.sh UKW/UKW-2025-12-05_prepared.json
# → erzeugt: UKW-2025-12-05_prepared_put.json

# 4. Upload
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @UKW/UKW-2025-12-05_prepared_put.json
```

## Warum "Remove-Broken" statt "Repair"?

| Ansatz | Vorteile | Nachteile |
| :--- | :--- | :--- |
| **Repair** (repair-bundle.sh) | Datenmenge bleibt gleich | Komplexer, lange Laufzeit, viele Dummy-Ressourcen |
| **Remove** (clean_bundle.sh) | **Sehr schnell, einfach, reproduzierbar** | Einige Ressourcen werden entfernt |

Da der Fokus dieser Übung auf **"Daten in den Server laden"** liegt und nicht auf "Data Engineering", ist **Remove-Broken** die bessere Wahl.

## Warum `transaction` statt `batch` für UKW/UKHD?

Die UKW/UKHD-Daten enthalten **zirkuläre Referenzen**: `Condition.encounter` verweist auf einen `Encounter`, und `Encounter.diagnosis[].condition` verweist zurück auf eine `Condition`. In einem **batch**-Bundle prüft der Server die referenzielle Integrität pro Eintrag sofort — eine Condition, deren Encounter noch nicht gespeichert ist, schlägt mit **HTTP 409 "Referential integrity violated"** fehl (und umgekehrt). In einem **transaction**-Bundle löst der Server die Referenzen innerhalb des Bundles auf und speichert alles atomar, wodurch zirkuläre Referenzen funktionieren.

Zusätzlich benennt `prepare_upload.sh` doppelte Ressourcen-IDs um (z. B. `Observation/LabResult-000000335` kommt in den UKW-Daten zweimal vor), damit beim späteren PUT-Upload keine URL-Kollisionen entstehen.

---

## Beispiel: UKSH Bundle (Hauptübung)

```bash
# 1. Musterdatenspende klonen
cd ~
git clone https://github.com/medizininformatik-initiative/musterdatenspende-diz.git
cd musterdatenspende-diz

# 2. UKSH entpacken
unzip UKSH/UKSH-2025-11-11.zip

# 3. Transaction-Bundle bauen
bash bin/merge-bundles.sh UKSH-2025-11-11/*.json > transaction-bundle.json

# 4. Bereinigen
bash /home/m3nthos/tool-kds-sandbox/solution-exercise-3/clean_bundle.sh transaction-bundle.json

# 5. POST → PUT umwandeln
bash /home/m3nthos/tool-kds-sandbox/solution-exercise-3/convert_to_put.sh transaction-bundle_cleaned.json

# 6. Upload
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @transaction-bundle_cleaned_put.json
```

---

## Beispiel: UKW/UKHD Bundle (optional, searchset → transaction)

```bash
# 1. Bundle nach /tmp kopieren
cp UKW/UKW-2025-12-05.json /tmp/

# 2. Bereinigen
bash /home/m3nthos/tool-kds-sandbox/solution-exercise-3/clean_bundle.sh /tmp/UKW-2025-12-05.json

# 3. Vorbereiten (searchset → transaction)
bash /home/m3nthos/tool-kds-sandbox/solution-exercise-3/prepare_upload.sh /tmp/UKW-2025-12-05_cleaned.json

# 4. POST → PUT umwandeln (erst jetzt ist das Bundle upload-bereit)
bash /home/m3nthos/tool-kds-sandbox/solution-exercise-3/convert_to_put.sh /tmp/UKW-2025-12-05_prepared.json

# 5. Upload
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @/tmp/UKW-2025-12-05_prepared_put.json
```