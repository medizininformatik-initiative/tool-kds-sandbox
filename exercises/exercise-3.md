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

|            | **UKSH** | **UKHD** | **UKW** |
| :--------- | :------ | :------- | :------- |
| **Datei(en)** | `UKSH/UKSH-2025-11-11.zip` | `UKHD/UKHD-2025-12-02.zip` | `UKW/UKW-2025-12-05.json` |
| **Bundle Type** | Einzelressourcen -> `transaction` | `searchset`-bundle | `searchset` |
| **Gesamt Ressourcen** | ~8.400 | ~1.400  | ~235 |
| **Referenzielle Integrität** | ❌ Nicht gegeben | ❌ Nicht gegeben | ❌ Nicht gegeben |

> 💡 **Womit beginnen?**  
> Für die UKSH-Daten wird ein `merge-bundles.sh`-Skript mitgeliefert, welches die Ressourcen in ein `transaction` bundle transformiert.  
> Dieses Bundle kann an den FHIR-Server gesendet werden, um die Ressourcen in den FHIR-Server zu laden.  

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

> ✅ **Ergebnis:** Du hast nun ein `transaction` bundle, welches Blaze verarbeiten kann, um mehrere Transaktionen auf eine Anfrage hin auszuführen.

___

## 🚫 3. Direct Upload versuchen

Manuellen Upload via `curl` probieren:
```bash
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @transaction-bundle.json
```

Die Antwort sollte ungefähr so aussehen:

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

> ✅ Wir haben nun gesehen, dass der Server die Daten **nicht** annehmen kann, weil Referenzen zwischen den Ressourcen nicht aufgelöst werden können.

---

## 🔍 4. Fehler-Diagnose: Referenzielle Integrität prüfen

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

> Für unsere Anwendungsfall, dass Ausprobieren und Lernen des Umgang mit FHIR-Daten, können wir nun entweder kaputte Referenzen reparieren, indem wir beispielsweise Dummy-Ressourcen ergänzen oder aber wir löschen die betreffenden Ressourcen, die fehlende Referenzen enthalten. **Ziel** ein *referenziell integeres* Bundle.

### Schritt A: Das Bereinigungsskript nutzen

```bash
# Kopiere das im Musterdatenspende-Repo erzeugte JSON in unseren Übungsordner  
cp ./transaction-bundle.json ~/tool-kds-sandbox/solution-exercise-3/

# Bereinigen:
cd ~/tool-kds-sandbox/solution-exercise-3/
bash ./clean_bundle.sh transaction-bundle.json
```

### Ergebnis

Es entsteht `transaction-bundle_cleaned.json` mit Ausgabe einer kurzen Zusammenfassung:

```text
===================================
Bundle cleaning summary
===================================
Original resources: 8451
Final resources: 8088
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

### Schritt B: Verifikation

Prüfe, ob die Bereinigung erfolgreich war:

```bash
bash ~/musterdatenspende-diz/bin/unresolved-references.sh ~/tool-kds-sandbox/solution-exercise-3/transaction-bundle_cleaned.json
```

✅ **Erwartetes Ergebnis:** `[]` (leere Liste = keine fehlenden Referenzen)

### Schritt C: Bundle anpassen – POST → PUT umwandeln

> **Warum?** `merge-bundles.sh` setzt für jeden Eintrag die HTTP-Methode **POST**.  
> **POST** bedeutet "lege neu an und vergib eine ID" – der Server ignoriert dabei die bereits in der Ressource stehende `id` und erzeugt eine neue, zufällige ID!  
> **PUT** bedeutet "schreibe unter dieser ID" – so bleiben die bereits vergebenen festen IDs in den Ressourcen (z. B. `PID-013b...`) erhalten und die Referenzen der Ressourcen bleiben bei Upload auflösbar.

```bash
cd ~/tool-kds-sandbox/solution-exercise-3/
bash ./convert_to_put.sh transaction-bundle_cleaned.json
# → erzeugt: transaction-bundle_cleaned_put.json
```

Prüfen:

```bash
jq '[.entry[].request.method] | unique' transaction-bundle_cleaned_put.json
# → ["PUT"]
```
___

## 📤 6. Manueller Upload

> **Ziel:** Manuellen Upload via `curl` erneut versuchen.

```bash
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @transaction-bundle_cleaned_put.json
```

Die Response des Servers umfasst den HTTP-Status jeder einzelnen Ressourcen des Bundles.

✅ **Erfolg!** Der Server hat die Ressourcen angelegt (Status `201 Created`).

___

## ✅ 7. Erfolgreichen Upload überprüfen

### Schritt A: Anzahl der Ressourcen abfragen

```bash
# Patienten
curl -s "http://localhost:8080/fhir/Patient?_summary=count" | jq '.total'

# Observationen
curl -s "http://localhost:8080/fhir/Observation?_summary=count" | jq '.total'
```

### Schritt B: Einzelne Ressource abfragen

```bash
# Eine Condition mit Angabe des zugehörigen Patienten finden
curl -s "http://localhost:8080/fhir/Condition?_count=1" | jq '.entry[0].resource | {id, subject, code: .code.coding}'

# Alternativ: Einen Patienten mit mindestens einer Condition finden
curl -s "http://localhost:8080/fhir/Patient?_has:Condition:patient&_count=1" | jq '.entry[0].resource.id'

# Mit dieser ID alle Conditions des Patienten abfragen
curl -s "http://localhost:8080/fhir/Condition?subject=Patient/<PID>" | jq '.entry[].resource | {id, code: .code.coding}'
```

___

## 🔄 8. Optional: Andere Bundles vorbereiten (UKHD, UKW)

### Vergleichstabelle

| Bundle | Type | Skripte    | Warum? |
| :----- | :--- | :---------- | :----- |
| **UKSH** |  `searchset`-Bundles -> `transaction`-Bundle | - musterdaten-diz/bin/<br>`merge-bundles.sh`<br> - tool-kds-sandbox/<br>`clean_bundle.sh`<br> - tool-kds-sandbox/<br>`convert_to_put.sh` | Einzeldateien zu `transaction`-Bundle mergen -><br> Referenzen cleanen -> <br> `PUT` als Transaktionsmethode setzen |
| **UKHD** | `searchset`-Bundles -> `transaction`-Bundle | - musterdaten-diz/bin/<br>`merge-bundles.sh`<br> - tool-kds-sandbox/<br>`clean_bundle.sh`<br> - tool-kds-sandbox/<br>`convert_to_put.sh` | Einzeldateien zu `transaction`-Bundle mergen -><br> Referenzen cleanen -> <br> `PUT` als Transaktionsmethode setzen |
| **UKW**  | `searchset`   | - tool-kds-sandbox/<br>`clean_bundle.sh`<br> - tool-kds-sandbox/<br>`prepare_upload.sh`<br> - tool-kds-sandbox/<br>`convert_to_put.sh` | Einzelnes Searchset cleanen -> <br> Umwandeln in `transaction` und reparieren von IDs -> <br> `PUT` als Transaktionsmethode setzen |

### Upload-Vorbereitung für UKHD-Musterdatensatz 
(analog zu UKSH)

```bash
# 1. Entpacken und Mergen
cd ~/musterdatenspende-diz/UKHD/
unzip UKHD-2025-12-02.zip
bash ../bin/merge-bundles.sh UKHD-2025-12-02/*.json > transaction-bundle.json

# 2. Bereinigen und auf PUT umstellen
cd ~/tool-kds-sandbox/solution-exercise-3/
bash ./clean_bundle.sh ~/musterdatenspende-diz/UKHD/transaction-bundle.json
bash convert_to_put.sh ~/musterdatenspende-diz/UKHD/transaction-bundle_cleaned.json

# 3. Upload
cd ~/musterdatenspende-diz/UKHD/
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @transaction-bundle_cleaned_put.json
```

### Upload-Vorbereitung für UKW-Musterdatensatz 
(Nur ein `searchset` gegeben, prepare_upload.sh übernimmt daher die Erstellung eines `transaction`-Bundles)

```bash
# 1. Bereinigen (wie bei UKSH)
cd ~/tool-kds-sandbox/solution-exercise-3
bash clean_bundle.sh ~/musterdatenspende-diz/UKW/UKW-2025-12-05.json

# 2. transaction-Bundle vorbereiten (nur bei searchset)
bash prepare_upload.sh ~/musterdatenspende-diz/UKW/UKW-2025-12-05_cleaned.json
# → erzeugt UKW-2025-12-05_cleaned_prepared.json

# 3. Upload Methode zu PUT konvertieren
bash convert_to_put.sh ~/musterdatenspende-diz/UKW/UKW-2025-12-05_cleaned_prepared.json

# 4. Upload
cd ~/musterdatenspende-diz/UKW/
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @UKW-2025-12-05_cleaned_prepared_put.json
```

___

## 📊 Übersicht: Ergebnisse aller drei Standorte

| Standort | Original | Nach Bereinigung | Removed |
| :--- | :--- | :--- | :--- |
| **UKSH** | 8,451 | 8,088 | 363 (Encounter, Location, etc.) |
| **UKW** | 235 | 234 | 1 (`MedicationAdministration`) |
| **UKHD** | 1,384 | 836 | 548 (`Medication`, `MedicationRequest`) |

___

## 🎯 Kurzzusammenfassung

| Konzept | Erklärung |
| :------ | :-------- |
| **Referenzielle Integrität** | In FHIR müssen Referenzen immer auf existierende Ressourcen zeigen. |
| **searchset vs. batch/transaction** | `searchset` = Read/Result (Response), `batch`/`transaction` = Write/Operation (Request). |
| **FHIR Bundle-Endpunkt** | POST an `/fhir` mit JSON-Bundle ist die Standard-Methode für Bulk-Import. |

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
