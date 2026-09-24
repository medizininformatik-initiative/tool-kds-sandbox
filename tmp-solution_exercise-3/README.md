# Lösung Exercise 3 – KDS-Beispieldaten in FHIR-Server laden

## Enthaltene Dateien

| Datei | Zweck |
|---|---|
| `clean_bundle.sh` | **Hauptwerkzeug:** Entfernt Ressourcen mit fehlenden Referenzen (automatisierte Bereinigung) |
| `prepare_upload.sh` | **Optional:** Konvertiert `searchset` → `batch` und fügt `request` Objekte hinzu |

## Verwendung (Empfohlener Workflow für Exercise 3)

### Hauptworkflow (UKSH - referenzielle Integrität):

```bash
# 1. Daten bereinigen
bash clean_bundle.sh /path/to/transaction-bundle.json
# → erzeugt: transaction-bundle_cleaned.json

# 2. Upload direkt (transaction bundle passt bereits)
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @transaction-bundle_cleaned.json
```

### Optional: Für UKW/UKHD (searchset bundles):

```bash
# 1. Daten bereinigen (wie oben)
bash clean_bundle.sh UKW/UKW-2025-12-05.json

# 2. Vorbereiten (searchset → batch Konvertierung)
bash prepare_upload.sh UKW/UKW-2025-12-05_cleaned.json
# → erzeugt: UKW-2025-12-05_upload_ready.json

# 3. Upload
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @UKW/UKW-2025-12-05_upload_ready.json
```

## Warum "Remove-Broken" statt "Repair"?

| Ansatz | Vorteile | Nachteile |
| :--- | :--- | :--- |
| **Repair** (repair-bundle.sh) | Datenmenge bleibt gleich | Komplexer, lange Laufzeit, viele Dummy-Ressourcen |
| **Remove** (clean_bundle.sh) | **Sehr schnell, einfach, reproduzierbar** | Einige Ressourcen werden entfernt |

Da der Fokus dieser Übung auf **"Daten in den Server laden"** liegt und nicht auf "Data Engineering", ist **Remove-Broken** die bessere Wahl.

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
bash /home/m3nthos/tool-kds-sandbox/tmp-solution_exercise-3/clean_bundle.sh transaction-bundle.json

# 5. Upload
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @transaction-bundle_cleaned.json
```

---

## Beispiel: UKW/UKHD Bundle (optional, searchset → batch)

```bash
# 1. Bundle nach /tmp kopieren
cp UKW/UKW-2025-12-05.json /tmp/

# 2. Bereinigen
bash /home/m3nthos/tool-kds-sandbox/tmp-solution_exercise-3/clean_bundle.sh /tmp/UKW-2025-12-05.json

# 3. Vorbereiten (searchset → batch)
bash /home/m3nthos/tool-kds-sandbox/tmp-solution_exercise-3/prepare_upload.sh /tmp/UKW-2025-12-05_cleaned.json

# 4. Upload
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @/tmp/UKW-2025-12-05_upload_ready.json
```