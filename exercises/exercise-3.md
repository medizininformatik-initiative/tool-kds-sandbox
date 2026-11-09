___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • **3 · Musterdaten laden** • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___

# 🟡 KDS-Beispieldaten in FHIR-Server laden

**Nächste Schritte:**

- Klone das Musterdatenspende-Repo und entpacke das UKSH-Bundle
- Baue das Transaction-Bundle und versuche den Upload
- Entdecke das Problem der referenziellen Integrität
- Bereinige die Daten automatisch
- Lade die Daten in den FHIR-Server und überprüfe den Upload
- Lade danach auch die Daten der Standorte UKHD und UKW

In den vorherigen Übungen haben wir gelernt, eigene FHIR-Profile und Instanzen zu definieren (Übung 1) und diese per `curl` in einen FHIR-Server hochzuladen (Übung 2).

Jetzt laden wir **echte Beispieldaten** aus der Medizininformatik-Initiative – die **Musterdatenspende der DIZe** (UKSH, UKHD, UKW).

___

## 📋 Schnellübersicht: Musterdatensätze im Vergleich

|            | **UKSH** | **UKHD** | **UKW** |
| :--------- | :------ | :------- | :------- |
| **Datei(en)** | `UKSH/UKSH-2025-11-11.zip` | `UKHD/UKHD-2025-12-02.zip` | `UKW/UKW-2025-12-05.json` |
| **Bundle-Typ** | Einzelressourcen -> `transaction` | `searchset`-Bundle | `searchset` |
| **Ressourcen gesamt** | ~8.400 | ~1.400  | ~235 |
| **Referenzielle Integrität** | ❌ Nicht gegeben | ❌ Nicht gegeben | ❌ Nicht gegeben |

> 💡 **Womit beginnen?**  
> Für die UKSH-Daten wird ein `merge-bundles.sh`-Skript mitgeliefert, welches die Ressourcen in ein `transaction`-Bundle transformiert.  
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

> ✅ **Ergebnis:** Du hast nun ein `transaction`-Bundle, welches Blaze verarbeiten kann, um mehrere Transaktionen auf eine Anfrage hin auszuführen.

___

## 🚫 3. Direkten Upload versuchen

Manuellen Upload via `curl` probieren:
```bash
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @transaction-bundle.json | jq
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

Der Server nimmt das Bundle **nicht** an: Eine Referenz lässt sich nicht auflösen. Woran das liegt, untersuchst du im nächsten Schritt.

---

## 🔍 4. Fehler-Diagnose: Referenzielle Integrität prüfen

Blaze meldet nur **eine** Referenz, die er nicht auflösen kann. Bevor du etwas änderst, siehst du dir diese eine Stelle an und verschaffst dir dann einen Überblick über alle.

### 4.1 Die gemeldete Stelle ansehen

Steht die Location aus der Fehlermeldung im Bundle?

```bash
jq '.entry[].resource | select(.id == "LMED1-LINAS1") | {resourceType, id, name, partOf}' transaction-bundle.json
```

✅ **Erwartetes Ergebnis:**

```json
{
  "resourceType": "Location",
  "id": "LMED1-LINAS1",
  "name": "Interdisziplinäre Notaufnahme Lübeck",
  "partOf": {
    "reference": "Location/LMED1"
  }
}
```

Die Location ist also da. Warum findet Blaze sie trotzdem nicht? Sieh dir an, wie das Bundle die Ressourcen anlegen will:

```bash
jq '.entry[0].request' transaction-bundle.json
# → { "method": "POST", "url": "Patient" }
```

🧩 **Was du gerade gesehen hast:**

- Bei `POST` vergibt der Server **neue** IDs und übernimmt die `id` aus der Ressource nicht. Die Location heißt in Blaze danach nicht mehr `LMED1-LINAS1`, und jede Referenz `Location/LMED1-LINAS1` zeigt ins Leere. Das behebst du in [Schritt 5C](#schritt-c-bundle-anpassen--post--put-umwandeln) mit `PUT`.
- Die Location selbst verweist mit `partOf` auf ihre übergeordnete Einheit `Location/LMED1`. Ob es die gibt, zeigt die nächste Prüfung.

### 4.2 Überblick: Welche Referenzen zeigen ins Leere?

Das Skript `unresolved-references.sh` aus dem Musterdatenspende-Repo sammelt alle Referenzen im Bundle und gibt die aus, zu denen es **keine** Ressource im Bundle gibt:

```bash
bash bin/unresolved-references.sh transaction-bundle.json
```

Die Ausgabe ist eine lange Liste, z. B.:

```json
[
  "Encounter/PV-1e5148db8b6ad2187d474ef16b4cb67c39b539bdf4c1c32714973385",
  "Encounter/PV-2df78028016f97660cb1815305934272752a1014a4bb9815994a8e76",
  ...
  "Location/LMED1",
  ...
]
```

Zähle sie nach Ressourcentyp. `jq -r '.[]'` gibt jede Referenz als eine Zeile aus, `cut -d/ -f1` behält nur den Teil vor dem `/`:

```bash
bash bin/unresolved-references.sh transaction-bundle.json | jq -r '.[]' | cut -d/ -f1 | sort | uniq -c
```

✅ **Erwartetes Ergebnis:**

```text
     10 Encounter
     34 Location
```

### 4.3 Wer verweist auf die fehlenden Ressourcen?

`Location/LMED1` steht in der Liste, die übergeordnete Einheit der Notaufnahme fehlt also im Bundle. Und wer verweist auf die Notaufnahme? `jq -c` gibt jede Ressource als **eine Zeile** aus, `grep` sucht darin wie in einer Textdatei:

```bash
jq -c '.entry[].resource' transaction-bundle.json \
  | grep '"Location/LMED1-LINAS1"' \
  | jq -r '"\(.resourceType)/\(.id)"'
```

✅ **Erwartetes Ergebnis** (8 Zeilen, IDs gekürzt):

```text
Encounter/PV-AK-6ef660fcf49b1bf7d16b3c93…
Encounter/PV-VK-4e2f02c9a84e8482fc4137a4…
...
```

🧩 **Was du gerade gesehen hast:**

- Die Referenzen bilden eine Kette: **Encounter** → Station (`Location/LMED1-LINAS1`, im Bundle) → Abteilung (`Location/LMED1`, **fehlt**). Fehlt das letzte Glied, entfernt die Bereinigung in Schritt 5 die ganze Kette: erst die Station, dann die Encounter, die auf sie verweisen.
- Die Encounter-IDs beginnen mit `PV-AK-` und `PV-VK-`: Abteilungs- und Versorgungsstellenkontakte. In den UKSH-Daten verweisen nur diese Kontaktebenen auf Locations.
- Die 10 fehlenden Encounter aus 4.2 betreffen dagegen u. a. Diagnosen, Laborwerte und Befunde, die auf einen Fall verweisen, der nicht im Bundle steht.
- Das Muster `jq -c … | grep … | jq -r` begegnet dir in den folgenden Übungen wieder: Es findet zu einem auffälligen Wert die Ressourcen, in denen er vorkommt.

___

## 🧹 5. Lösung: Daten bereinigen (`clean_bundle.sh`)

> Für unseren Anwendungsfall, das Ausprobieren und Lernen des Umgangs mit FHIR-Daten, können wir nun entweder kaputte Referenzen reparieren, indem wir beispielsweise Dummy-Ressourcen ergänzen, oder wir löschen die betreffenden Ressourcen, die fehlende Referenzen enthalten. **Ziel:** ein *referenziell integres* Bundle.

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

🧩 **Was du gerade gesehen hast:**

- **Location 63:** alle Locations des Bundles. Jede verweist mit `partOf` auf eine der 34 fehlenden übergeordneten Einheiten.
- **Encounter 219:** alle Encounter, die auf eine Location verweisen. 73 davon verweisen direkt auf eine fehlende Location, die übrigen 146 auf eine Station, die das Skript zuvor entfernt hat. Deshalb arbeitet das Skript **iterativ**, bis keine offene Referenz mehr übrig ist.
- **Condition, Observation, DiagnosticReport, ServiceRequest:** Ressourcen, die auf einen der 10 fehlenden Encounter verweisen.

Was das Entfernen kostet, zeigt ein Vergleich der Kontaktebenen vorher und nachher:

```bash
for f in transaction-bundle.json transaction-bundle_cleaned.json; do
  echo "== $f"
  jq -r '.entry[].resource | select(.resourceType == "Encounter") | .type[0].coding[0].code' $f | sort | uniq -c
done
```

✅ **Erwartetes Ergebnis:**

```text
== transaction-bundle.json
    109 abteilungskontakt
   1170 einrichtungskontakt
    110 versorgungsstellenkontakt
== transaction-bundle_cleaned.json
   1170 einrichtungskontakt
```

🧩 **Was du gerade gesehen hast:** Nach der Bereinigung gibt es nur noch Einrichtungskontakte. Welche Abteilung oder Station einen Fall betreut hat, steht nicht mehr in den Daten. Für die Übungen ist das in Ordnung. Im DIZ-Alltag könnte man stattdessen die fehlenden Locations beim Standort nachfordern.

### Schritt B: Verifikation

Prüfe, ob die Bereinigung erfolgreich war:

```bash
bash ~/musterdatenspende-diz/bin/unresolved-references.sh ~/tool-kds-sandbox/solution-exercise-3/transaction-bundle_cleaned.json
```

✅ **Erwartetes Ergebnis:** `[]` (leere Liste = keine fehlenden Referenzen)

### Schritt C: Bundle anpassen – POST → PUT umwandeln

> **Warum?** `merge-bundles.sh` setzt für jeden Eintrag die HTTP-Methode **POST**.  
> **POST** bedeutet "lege neu an und vergib eine ID" – der Server ignoriert dabei die bereits in der Ressource stehende `id` und erzeugt eine neue, zufällige ID!  
> **PUT** bedeutet "schreibe unter dieser ID" – so bleiben die bereits vergebenen festen IDs in den Ressourcen (z. B. `PID-013b...`) erhalten und die Referenzen der Ressourcen bleiben beim Upload auflösbar.

```bash
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
  --data @transaction-bundle_cleaned_put.json \
  | jq '[.entry[].response.status] | group_by(.) | map({(.[0]): length}) | add'
```

Die Response des Servers ist ein Bundle vom Typ `transaction-response` mit einem Eintrag pro Ressource. Statt alle rund 8.000 Einträge auszugeben, zählt `jq` hier, wie oft welcher HTTP-Status vorkommt.

✅ **Erfolg!** Der Server hat alle Ressourcen angelegt:

```text
{
  "201": 8083
}
```

> 💡 `201` bedeutet „neu angelegt“. Lädst du dasselbe Bundle ein zweites Mal hoch, antwortet der Server mit `200` („aktualisiert“), weil die Ressourcen unter diesen IDs schon existieren.
>
> ⚠️ Erscheint stattdessen `jq: error ... Cannot iterate over null`, hat der Server das Bundle abgelehnt und ein `OperationOutcome` statt eines Bundles zurückgegeben. Wiederhole den Befehl dann ohne den `jq`-Filter (nur `| jq`), um die Fehlermeldung zu lesen.

___

## ✅ 7. Erfolgreichen Upload überprüfen

### Schritt A: Anzahl der Ressourcen abfragen

```bash
# Patienten
curl -s "http://localhost:8080/fhir/Patient?_summary=count" | jq '.total'
# → mind. 271 (zzgl. deiner Testpatienten aus Übung 2)

# Observationen
curl -s "http://localhost:8080/fhir/Observation?_summary=count" | jq '.total'
# → mind. 3481 (aus dem Bundle und deine HbA1c-Observation aus Übung 2)
```

### Schritt B: Einzelne Ressource abfragen

```bash
# Eine Condition mit Angabe des zugehörigen Patienten finden
curl -s "http://localhost:8080/fhir/Condition?_count=1" | jq '.entry[0].resource | {id, subject, code: .code.coding}'

# Einen Patienten mit mindestens einer Condition finden
curl -s "http://localhost:8080/fhir/Condition?_count=1&_include=Condition:subject" \
  | jq -r '.entry[] | select(.resource.resourceType=="Patient") | .resource.id'

# Mit dieser ID alle Conditions des Patienten abfragen
curl -s "http://localhost:8080/fhir/Condition?subject=Patient/<PID>" | jq '.entry[].resource | {id, code: .code.coding}'
```

___

## 🔄 8. Weitere Standorte laden (UKHD, UKW)

Lade jetzt auch die Daten der beiden anderen Standorte. Sie sind kleiner, bringen aber andere Besonderheiten mit, z. B. ältere Profilversionen. Die folgenden Übungen nutzen die Daten aller drei Standorte.

### Vergleichstabelle

| Bundle | Typ | Skripte    | Warum? |
| :----- | :--- | :---------- | :----- |
| **UKSH** |  `searchset`-Bundles -> `transaction`-Bundle | - musterdatenspende-diz/bin/<br>`merge-bundles.sh`<br> - tool-kds-sandbox/<br>`clean_bundle.sh`<br> - tool-kds-sandbox/<br>`convert_to_put.sh` | Einzeldateien zu `transaction`-Bundle mergen -><br> Referenzen cleanen -> <br> `PUT` als Transaktionsmethode setzen |
| **UKHD** | `searchset`-Bundles -> `transaction`-Bundle | - musterdatenspende-diz/bin/<br>`merge-bundles.sh`<br> - tool-kds-sandbox/<br>`clean_bundle.sh`<br> - tool-kds-sandbox/<br>`convert_to_put.sh` | Einzeldateien zu `transaction`-Bundle mergen -><br> Referenzen cleanen -> <br> `PUT` als Transaktionsmethode setzen |
| **UKW**  | `searchset`   | - tool-kds-sandbox/<br>`clean_bundle.sh`<br> - tool-kds-sandbox/<br>`prepare_upload.sh`<br> - tool-kds-sandbox/<br>`convert_to_put.sh` | Einzelnes Searchset cleanen -> <br> Umwandeln in `transaction` und Reparieren von IDs -> <br> `PUT` als Transaktionsmethode setzen |

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
  --data @transaction-bundle_cleaned_put.json \
  | jq '[.entry[].response.status] | group_by(.) | map({(.[0]): length}) | add'
# → { "201": 823 }
```

### Upload-Vorbereitung für UKW-Musterdatensatz
(gegeben ist ein `searchset`, prepare_upload.sh übernimmt die Erstellung eines `transaction`-Bundles)

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
  --data @UKW-2025-12-05_cleaned_prepared_put.json \
  | jq '[.entry[].response.status] | group_by(.) | map({(.[0]): length}) | add'
# → { "201": 234 }
```

___

## 📊 Übersicht: Ergebnisse aller drei Standorte

| Standort | Original | Nach Bereinigung | Entfernt |
| :--- | :--- | :--- | :--- |
| **UKSH** | 8.446 | 8.083 | 363 (Encounter, Location, etc.) |
| **UKW** | 235 | 234 | 1 (`MedicationAdministration`) |
| **UKHD** | 1.371 | 823 | 548 (`Medication`, `MedicationRequest`) |

___

## 🎯 Kurzzusammenfassung

| Konzept | Erklärung |
| :------ | :-------- |
| **Referenzielle Integrität** | In FHIR müssen Referenzen immer auf existierende Ressourcen zeigen. |
| **searchset vs. batch/transaction** | `searchset` = Read/Result (Response), `batch`/`transaction` = Write/Operation (Request). |
| **FHIR Bundle-Endpunkt** | POST an `/fhir` mit JSON-Bundle ist die Standard-Methode für Bulk-Import. |

___

### Ausblick

- **Übung 4:** Query von KDS-Daten (Strukturierte Abfragen, Chaining, AND-Suche)
- **Übung 5:** Terminologien prüfen mit FHIR-Operationen (Codes aus den Musterdaten am Terminologieserver prüfen)
- **Übung 6:** Terminologieserver mit deutschen Klassifikationen einrichten und den MII FHIR Validator nutzen

___

___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • **3 · Musterdaten laden** • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___
