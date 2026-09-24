___
___
[Prerequisites](prerequisites.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • **Exercise 3** • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
___
___

# 🟡 KDS-Beispieldaten in FHIR-Server laden

**Nächste Schritte:**

- Klone das Musterdatenspende-Repo und entpacke das UKSH-Bundle
- Baue das Transaction-Bundle und versuche den Upload
- Entdecke das "Referenzielle Integrität"-Problem
- Bereinige die Daten automatisch
- Lade die Daten in den FHIR-Server und überprüfe den Upload

In den vorherigen Übungen haben wir gelernt, eigene FHIR-Profile und Instanzen zu definieren (Exercise 1) und diese per `curl` in einen FHIR-Server hochzuladen (Exercise 2).

Jetzt laden wir **echte Beispieldaten** aus der Medizininformatik-Initiative – die **Musterdatenspende der DIZe** (UKSH, UKHD, UKW).

___

## 📋 Schnellübersicht: Musterdatensätze im Vergleich

| | **UKSH** | **UKW** | **UKHD** |
| :--- | :--- | :--- | :--- |
| **Datei** | `transaction-bundle.json` | `UKW/UKW-2025-12-05.json` | `UKHD/UKHD-2025-12-02/0002690836.json` |
| **Bundle Type** | `transaction` | `searchset` | `searchset` |
| **Gesamt Ressourcen** | ~8.400 | ~235 | ~1.300 |
| **Referenzielle Integrität** | ❌ Nicht gegeben | ❌ Nicht gegeben | ❌ Nicht gegeben |
| **Für diesen Workflow** | ✅ Hauptübung | 🔁 Nach UKSH | 🔁 Nach UKSH |

> 💡 **Warum ist UKSH der Hauptweg?**  
> UKSH erzeugt mit `merge-bundles.sh` ein `transaction` bundle – das ist **exakt das Format**, das Blaze erwartet.  
> Das Problem ist also **nicht** die Bundle-Form, sondern die **referenzielle Integrität** (fehlende Referenzen).  
> Das lernst du in dieser Übung – und danach weißt du auch, was du mit UKW/UKHD machen musst.

___

## 🚀 1. Musterdatenspende klonen & UKSH entpacken

```bash
cd ~
git clone https://github.com/medizininformatik-initiative/musterdatenspende-diz.git
cd musterdatenspende-diz

# UKSH entpacken (ca. 270 JSON-Dateien)
unzip UKSH/UKSH-2025-11-11.zip
```

___

## 🛠️ 2. Transaction-Bundle bauen

```bash
# Aus dem UKSH-Verzeichnis das Bundle erzeugen
bash bin/merge-bundles.sh UKSH-2025-11-11/*.json > transaction-bundle.json

# Prüfe das Bundle
jq '.type' transaction-bundle.json      # → "transaction"
jq '.entry | length' transaction-bundle.json  # → ~8.400 Einträge
```

> ✅ **Ergebnis:** Du hast ein `transaction` bundle – genau das Format, das Blaze erwartet.

___

## 🚫 3. Versuch 1: Direct Upload (scheitert!)

> ⚠️ **Ziel:** Den Fehler selbst erleben – das ist der beste Lernweg.

### Schritt A: Upload versuchen

```bash
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @transaction-bundle.json
```

### Schritt B: Der Fehler

Die Antwort sollte so aussehen (Auszug):

```json
{
  "resourceType": "OperationOutcome",
  "issue": [{
    "severity": "error",
    "code": "conflict",
    "diagnostics": "Referential integrity violated. Resource `Location/LMED1-LINAS1` cannot be found."
  }]
}
```

> ✅ **Lernziel erreicht:** Wir haben gesehen, dass der Server die Daten **nicht** annehmen kann, weil Referenzen nicht aufgelöst werden können.

---

## 🔍 4. Diagnose: Referenzielle Integrität prüfen

```bash
bash bin/unresolved-references.sh transaction-bundle.json
```

Die Ausgabe ist eine Liste der fehlenden IDs, z. B.:

```json
[
  "Location/LMED1-LINAS1",
  "Location/LMED1",
  "Encounter/PV-1e5148db8b6ad2187d474ef16b4cb67c39b539bdf4c1c32714973385",
  "Patient/dummy"
]
```

💡 **Erklärung:**  

- Die `Encounter` Ressourcen verweisen auf `Location`, aber diese sind im Bundle nicht enthalten.
- Ein `Encounter` verweist auf `Patient/dummy`, aber diesen Patienten gibt es nicht.

___

## 🧹 5. Lösung: Daten bereinigen (`clean_bundle.sh`)

> **Ziel:** Entferne alle Ressourcen, die auf fehlende Referenzen zeigen – so bleibt nur ein *referenziell integeres* Bundle.

### Schritt A: Das Bereinigungsskript nutzen

```bash
# Kopiere das im Musterdatenspende-Repo erzeugte JSON in unseren Übungsordner  
cp ./transaction-bundle.json ~/tool-kds-sandbox/solution-exercise-3/

# Bereinigen:
cd ~/tool-kds-sandbox/solution-exercise-3/
bash ./clean_bundle.sh transaction-bundle.json
```

### Ergebnis

Es entsteht `transaction-bundle_cleaned.json` mit einer Zusammenfassung:

```text
===================================
Bundle cleaning summary
===================================
Original resources: 8446
Final resources: 8083
Total removed: 363

Removed by resource type:
  Condition: 12
  DiagnosticReport: 7
  Encounter: 219
  Location: 63
  Observation: 55
  ServiceRequest: 7
===================================
```

### Schritt B: Verification

Prüfe, ob die Bereinigung erfolgreich war:

```bash
bash ~/musterdatenspende-diz/bin/unresolved-references.sh ~/tool-kds-sandbox/solution-exercise-3/transaction-bundle_cleaned.json
```

✅ **Erwartetes Ergebnis:** `[]` (leere Liste = keine fehlenden Referenzen)

___

## 📤 6. Upload via manual `curl`

> **Ziel:** Die Upload-Syntax selbst ausführen – das ist ein zentraler FHIR REST API Aufruf.

```bash
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @transaction-bundle_cleaned.json
```

Die Antwort sollte so aussehen (Auszug):

```json
{
  "resourceType": "Bundle",
  "type": "transaction-response",
  "entry": [{
    "response": {
      "status": "201",
      "location": "Patient/PID-013b68fc80dc51ce452717eb1647c91c9f26c8008755988e6baa0045/_history/123",
      "etag": "W/\"123\""
    }
  }]
}
```

✅ **Erfolg!** Der Server hat die Ressourcen angelegt (Status `201 Created`).

___

## ✅ 7. Upload überprüfen

### Schritt A: Anzahl der Ressourcen prüfen

```bash
# Patienten
curl -s "http://localhost:8080/fhir/Patient?_summary=count" | jq '.total'

# Observationen
curl -s "http://localhost:8080/fhir/Observation?_summary=count" | jq '.total'

# Locations (inkl. derjenigen, die wir bewusst nicht entfernt haben)
curl -s "http://localhost:8080/fhir/Location?_summary=count" | jq '.total'
```

### Schritt B: Einzelne Ressource abfragen

```bash
# Einen Patienten finden
curl -s "http://localhost:8080/fhir/Patient?_count=1" | jq '.entry[0].resource.id'

# Mit dieser ID eine Condition abfragen
curl -s "http://localhost:8080/fhir/Condition?subject=Patient/<ID>&_count=3" | jq '.entry[].resource.code.coding'
```

___

## 🔄 8. Optional: Andere Bundles vorbereiten (UKW, UKHD)

### Vergleichstabelle

| Bundle | Type | Benötigt  | Warum? |
| :--- | :--- | :--- | :--- |
| **UKSH** | `transaction` | musterdaten-diz/bin/`merge-bundles.sh` + tool-kds-sandbox/`clean_bundle.sh` | Passt direkt zum Upload nach der Bereinigung |
| **UKW** | `searchset` | musterdaten-diz/bin/`merge-bundles.sh` + tool-kds-sandbox/`clean_bundle.sh` + `prepare_upload.sh` | Server akzeptiert nur `batch`/`transaction` |
| **UKHD** | `searchset` | musterdaten-diz/bin/`merge-bundles.sh` + tool-kds-sandbox/`clean_bundle.sh` + `prepare_upload.sh` | Server akzeptiert nur `batch`/`transaction` |

### Warum `searchset` → `batch`?

Ein `searchset` Bundle sieht so aus:

```json
{
  "type": "searchset",
  "entry": [{
    "resource": { "resourceType": "Patient", ... },
    "search": { "mode": "match" }  // ← Für Suchergebnisse
  }]
}
```

Ein `batch` Bundle hingegen:

```json
{
  "type": "batch",
  "entry": [{
    "resource": { "resourceType": "Patient", ... },
    "request": {                    // ← Für Write-Operationen
      "method": "POST",
      "url": "Patient"
    }
  }]
}
```

### Schritt-für-Schritt für UKW/UKHD

```bash
# 1. Kopiere das Skript
cp ~/tool-kds-sandbox/tmp-solution_exercise-3/prepare_upload.sh /tmp/

# 2. Bereinigen (wie bei UKSH)
bash /tmp/clean_bundle.sh UKW/UKW-2025-12-05.json

# 3. Vorbereiten (nur bei searchset)
bash /tmp/prepare_upload.sh UKW/UKW-2025-12-05_cleaned.json
# → erzeugt UKW-2025-12-05_upload_ready.json

# 4. Upload
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @UKW/UKW-2025-12-05_upload_ready.json
```

___

## 📊 Übersicht: Ergebnisse aller drei Standorte

| Standort | Original | Nach Bereinigung | Removed | Upload Status |
| :--- | :--- | :--- | :--- | :--- |
| **UKSH** | 8,446 | 8,083 | 363 (Encounter, Location, etc.) | ✅ Erfolg |
| **UKW** | 235 | 234 | 1 (`MedicationAdministration`) | ✅ Erfolg |
| **UKHD** | 1,287 | 739 | 548 (`Medication`, `MedicationRequest`) | ✅ Erfolg |

___

## 🎯 Was du gelernt hast

| Konzept | Erklärung |
| :--- | :--- |
| **Referenzielle Integrität** | In FHIR müssen Referenzen immer auf existierende Ressourcen zeigen. |
| **searchset vs. batch/transaction** | `searchset` = Read/Result, `batch`/`transaction` = Write/Operation (Server erwartet后者). |
| **Automatisierte Bereinigung** | Entferne defekte Ressourcen statt manuell zu reparieren – schneller und konsistent. |
| **curl für FHIR** | `POST /fhir` mit JSON-Bundle ist die Standard-Methode für Bulk-Import. |

___

## 🚀 Ausblick: Nächste Schritte

- **Ex4:** Query von KDS-Daten (Strukturierte Abfragen, Chaining, AND-Suche)
- **Ex5:** Lokalen Terminologieserver aufsetzen (ICD-10-GM, LOINC, SNOMED-CT importieren)
- **Ex6:** MII FHIR Validator nutzen (Ressourcen/Profile checken)

___

___
___
[Prerequisites](prerequisites.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • **Exercise 3** • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
___
___
