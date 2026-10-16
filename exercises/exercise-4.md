___
___
[Prerequisites](prerequisites.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • **Exercise 4** • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
___
___

# 🟠 Query von KDS-Daten

**Nächste Schritte:**  

- Prüfe, ob die UKSH-Musterdaten aus Exercise 3 im FHIR-Server liegen
- Erkunde Patienten, Diagnosen und Laborwerte mit FHIR-Search
- Verknüpfe Ressourcen über Chaining, `_has`, `_include` und `_revinclude`
- Entdecke Auffälligkeiten in den Daten

___

## Einführung & Kontext

In [Exercise 3](exercise-3.md) haben wir die **Musterdatenspende des UKSH** bereinigt und in den lokalen FHIR-Server (Blaze) geladen – rund 8.100 Ressourcen von 272 pseudonymisierten Patienten.

In dieser Übung stellst du **strukturierte Abfragen** auf diese KDS-Daten: Du suchst nach Diagnosen (ICD-10-GM), Laborwerten (LOINC), Prozeduren (OPS), verknüpfst Ressourcen miteinander und stößt dabei auf typische Eigenheiten echter DIZ-Daten.

> 💡 **Warum FHIR-Search?**  
> FHIR-Search dient als standardisierte API-Schnittstelle zu FHIR-Datenrepositorien. Dadurch wird ein standortübergreifend einheitlicher Zugriff auf die im DIZ integrierten Daten möglich.

> 💡 **Ausblick: TORCH & DIMP/DUP**  
> Für komplexe Datenanforderungen (z. B. kohortenbasierte Extraktion mit Consent-Check) gibt es im MII-Ökosystem spezialisierte Tools:
>
> - **[TORCH](https://github.com/medizininformatik-initiative/torch)**: Ein FHIR®-Extraction-Tool für strukturierte, consent-konforme Datenextraktion. TORCH Ausleitungen werden als **CRTDL** (Clinical Resource Transfer Definition Language) definiert und können entweder CQL oder FLARE für die Abfrage der Kohorte im FHIR-Server verwenden. Ziel: Batch-Extraktion für Forschungsanfragen inkl. MII Consent-Handling.
> - **DIMP/DUP-Pipeline (aether-orchestriert)**: DUP = Data Usage Project / Forschungsprojekte erfordern eine Vereinheitlichung bei Extraktion sowie De-identifikation, Maskierung und Pseudonymisierung (kurz DIMP) der bereitzustellenden Daten. Die Ausleitung wird bei Verwendung von TORCH mittels aether orchestriert.
>
> Diese Tools sind **nicht Bestandteil dieser praktischen Übung**, aber es ist wichtig zu wissen, dass sie im DIZ-Alltag für large-scale oder consent-komplexe Datenanfragen eingesetzt werden. TORCH ersetzt nicht FHIR-Search, sondern erweitert es um Projekt-basierte, auditierbare Extraktionsketten.

___

📋 **Übersicht:**

- [Vorbereitung: Datenbestand prüfen](#️-0-vorbereitung-datenbestand-prüfen)
- [Hintergrund: Aufbau einer Suchanfrage](#-1-hintergrund-aufbau-einer-suchanfrage)
- [Patienten erkunden](#-2-patienten-erkunden)
- [Diagnosen (ICD-10-GM)](#-3-diagnosen-icd-10-gm)
- [Laborwerte (LOINC)](#-4-laborwerte-loinc)
- [Ressourcen verknüpfen](#-5-ressourcen-verknüpfen)
- [Auffälligkeiten in den Daten](#-6-auffälligkeiten-in-den-daten)
- [Skriptbasierter Ausblick (Python/R)](#-7-skriptbasierter-ausblick-pythonr)
- [Zusammenfassung & Merkregeln](#-zusammenfassung--merkregeln)

___

## 🛠️ 0. Vorbereitung: Datenbestand prüfen

> ⚠️ **Voraussetzung:** Blaze läuft auf `http://localhost:8080` (aus [Exercise 2](exercise-2.md#container-definieren-und-starten)) und die bereinigten UKSH-Daten sind per `PUT` hochgeladen ([Exercise 3](exercise-3.md)).

Zähle die Ressourcen pro Typ – `_summary=count` liefert nur die Anzahl, keine Ressourcen:

```bash
for type in Patient Encounter Condition Observation Procedure DiagnosticReport ServiceRequest Consent; do
  echo "$type: $(curl -s "http://localhost:8080/fhir/$type?_summary=count" | jq '.total')"
done
```

✅ **Erwartetes Ergebnis** (nur UKSH geladen):

```text
Patient: 272
Encounter: 1172
Condition: 425
Observation: 3482
Procedure: 180
DiagnosticReport: 1276
ServiceRequest: 1276
Consent: 5
```

> 💡 **Hinweis:** Hast du zusätzlich UKHD oder UKW hochgeladen, sind die Zahlen in dieser Übung entsprechend höher. Die Abfragen funktionieren trotzdem.

___

## 📖 1. Hintergrund: Aufbau einer Suchanfrage

Eine FHIR-Suche hat immer die Form `GET [Basis-URL]/[Ressourcentyp]?[Parameter]=[Wert]&...`. Der Server antwortet mit einem `Bundle` vom Typ `searchset`.

| Parameter | Funktion | Beispiel |
| --------- | -------- | -------- |
| `_id` | Nach ID filtern | `Patient?_id=PID-...` |
| `_count` | Einträge pro Seite | `Patient?_count=5` |
| `_summary=count` | Nur Anzahl zurückgeben | `Condition?_summary=count` |
| `_elements` | Nur bestimmte Elemente zurückgeben | `Patient?_elements=gender,birthDate` |
| Token (`code`, `gender`, `class`, …) | Codes suchen, optional mit System: `system\|code` | `Condition?code=http://fhir.de/CodeSystem/bfarm/icd-10-gm\|C20` |
| Datum (`birthdate`, `date`, …) | Mit Präfixen `lt`, `le`, `gt`, `ge`, `eq` | `Patient?birthdate=lt1950` |
| Menge (`value-quantity`) | Zahlenwert mit Präfix, optional Einheit | `Observation?value-quantity=gt5` |
| Referenz (`subject`, `encounter`) | Auf andere Ressourcen verweisen | `Condition?subject=Patient/PID-...` |
| Chaining (`subject:Patient.gender`) | Über eine Referenz hinweg filtern | `Condition?subject:Patient.gender=female` |
| Reverse Chaining (`_has`) | Nach Ressourcen filtern, die auf mich verweisen | `Patient?_has:Condition:subject:code=C20` |
| `_include` / `_revinclude` | Verknüpfte Ressourcen mitliefern | `DiagnosticReport?_include=DiagnosticReport:result` |

> 💡 **Merke:** Mehrere Parameter werden mit **UND** verknüpft. Mehrere Werte im selben Parameter, durch Komma getrennt, bedeuten **ODER**: `code=C20,C18`.
>
> ⚠️ **Server-Unterschiede:** Nicht jeder FHIR-Server unterstützt jeden Parameter. Blaze kann z. B. mit `_sort` nur nach `_id` und `_lastUpdated` sortieren. Was ein Server kann, steht in seinem `CapabilityStatement` (`/fhir/metadata`).

___

## 💻 2. Patienten erkunden

### Abfrage 2.1: Einen Patienten ansehen

```bash
curl -s "http://localhost:8080/fhir/Patient?_count=1" | jq '.entry[0].resource'
```

🔍 **Genau hinschauen:** Die Patienten haben **keinen Namen** und keine vollständige Adresse. Sie sind **pseudonymisiert**: Statt eines Namens gibt es nur einen `identifier` mit dem System `https://www.medizininformatik-initiative.de/fhir/sid/pseudonym`, das Geburtsdatum ist auf Jahr und Monat gekürzt (z. B. `1970-09`). So sehen Daten aus, die ein DIZ für die Forschung bereitstellt.

### Abfrage 2.2: Patienten nach Geschlecht und Alter

```bash
# Weibliche Patienten
curl -s "http://localhost:8080/fhir/Patient?gender=female&_summary=count" | jq '.total'
# → 75

# Vor 1950 geboren
curl -s "http://localhost:8080/fhir/Patient?birthdate=lt1950&_summary=count" | jq '.total'
# → 23
```

### Abfrage 2.3: Blättern durch Ergebnisse (Pagination)

Große Ergebnismengen liefert der Server seitenweise. Die nächste Seite steht als Link mit `relation: "next"` im Bundle:

```bash
# Erste Seite mit 5 Patienten
curl -s "http://localhost:8080/fhir/Patient?_count=5" | jq '{total, ids: [.entry[].resource.id[0:20]], next: (.link[] | select(.relation == "next") | .url)}'

# Nächste Seite abrufen: den "next"-Link in Anführungszeichen einsetzen
curl -s "<next-URL>" | jq '[.entry[].resource.id[0:20]]'
```

> 💡 **Merke:** `total` ist die Gesamtanzahl der Treffer, `entry` enthält nur die Ressourcen der aktuellen Seite.

___

## 💻 3. Diagnosen (ICD-10-GM)

Alle Diagnosen der UKSH-Daten sind mit **ICD-10-GM** kodiert (`http://fhir.de/CodeSystem/bfarm/icd-10-gm`).

### Abfrage 3.1: Häufigste Diagnosen

Zum Auswerten holen wir alle 425 Diagnosen auf einer Seite und zählen die Codes mit `jq`:

```bash
curl -s "http://localhost:8080/fhir/Condition?_count=500" \
  | jq '[.entry[].resource.code.coding[0].code] | group_by(.) | map({code: .[0], anzahl: length}) | sort_by(-.anzahl) | .[0:8]'
```

✅ **Erwartetes Ergebnis (Auszug):**

| ICD-10-GM | Anzahl | Bedeutung |
| --------- | ------ | --------- |
| `Z11` | 27 | Spezielle Verfahren zur Untersuchung auf infektiöse und parasitäre Krankheiten |
| `C20` | 23 | Bösartige Neubildung des Rektums |
| `R51` | 21 | Kopfschmerz |
| `I45.2` | 19 | Bifaszikulärer Block |
| `R11` | 15 | Übelkeit und Erbrechen |
| `U99.0` | 13 | Spezielle Verfahren zur Untersuchung auf SARS-CoV-2 |

🔍 **Genau hinschauen:** Die Diagnosen enthalten nur den Code, **keinen Klartext** (`display`). Die Bedeutung musst du nachschlagen – genau dafür richten wir in [Exercise 5](exercise-5.md) einen Terminologieserver ein.

### Abfrage 3.2: Alle Rektumkarzinom-Diagnosen (C20)

```bash
curl -s "http://localhost:8080/fhir/Condition?code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|C20&_count=50" \
  | jq '{diagnosen: .total, patienten: ([.entry[].resource.subject.reference] | unique | length)}'
```

✅ **Erwartetes Ergebnis:** `23` Diagnosen bei nur `5` Patienten.

💡 **Warum mehr Diagnosen als Patienten?** Eine Diagnose wird pro Fall (`Encounter`) dokumentiert. Wer mehrfach stationär behandelt wird, hat die gleiche Diagnose mehrfach.

___

## 💻 4. Laborwerte (LOINC)

Die UKSH-Daten enthalten 1.888 Laborwerte im KDS-Profil `ObservationLab`. Anders als das HbA1c-Beispiel aus [Exercise 1](exercise-1.md) sind hier z. B. Hämoglobin, Kalium und Natrium enthalten.

### Abfrage 4.1: Hämoglobin – LOINC vs. lokaler Code

Jeder Laborwert trägt einen **lokalen Laborcode** des UKSH und – wenn vorhanden – zusätzlich einen **LOINC-Code**:

```bash
# Hämoglobin über LOINC
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|718-7&_summary=count" | jq '.total'
# → 32

# Hämoglobin über den lokalen UKSH-Code
curl -s "http://localhost:8080/fhir/Observation?code=http://medic.uksh.de/fhir/CodeSystem/Laborparameter|LAB_hbe&_summary=count" | jq '.total'
# → 31
```

```bash
# Wie viele Laborwerte haben überhaupt einen LOINC-Code?
curl -s "http://localhost:8080/fhir/Observation?category=laboratory&_summary=count" | jq '.total'
# → 1888
curl -s "http://localhost:8080/fhir/Observation?category=laboratory&code=http://medic.uksh.de/Codeystem/unknown|Unknown&_summary=count" | jq '.total'
# → 819
```

🔍 **Genau hinschauen:** 819 von 1.888 Laborwerten (über 40 %) haben **keinen LOINC-Code**, sondern nur einen lokalen Code. Eine standortübergreifende Abfrage per LOINC findet diese Werte nicht. Das Mapping lokaler Codes auf LOINC ist eine zentrale Aufgabe im DIZ.

### Abfrage 4.2: Auffällige Werte finden – Hyperkaliämie

Kalium (`6298-4`) über 5 mmol/L:

```bash
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|6298-4&value-quantity=gt5|http://unitsofmeasure.org|mmol/L" \
  | jq '[.entry[].resource | {datum: .effectiveDateTime[0:10], wert: .valueQuantity.value, einheit: .valueQuantity.unit, bewertung: .interpretation[0].coding[0].code}] | sort_by(.datum)'
```

✅ **Erwartetes Ergebnis:** 5 Werte zwischen 5,7 und 8,8 mmol/L, alle vom selben Patienten im Januar/Februar 2022.

> 💡 **Merke:** Bei `value-quantity` steht die Einheit als UCUM-Code hinter dem Wert: `[präfix][wert]|[system]|[code]`. Ohne Einheit (`gt5`) wird nur der Zahlenwert verglichen.
>
> 💡 **Sortieren:** Da Blaze nicht nach Datum sortieren kann, übernimmt das hier `jq` mit `sort_by(.datum)`.

### 🛠️ Aufgabe: Auffällige Laborwerte

- Finde alle Hämoglobin-Werte unter 10 g/dL. Wie viele Patienten sind betroffen?
- Finde Natrium-Werte (`2951-2`) unter 135 mmol/L (Hyponatriämie).

<details>
<summary>Lösung</summary>

```bash
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|718-7&value-quantity=lt10" \
  | jq '{werte: .total, patienten: ([.entry[].resource.subject.reference] | unique | length)}'
# → 6 Werte, 1 Patientin

curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|2951-2&value-quantity=lt135&_summary=count" | jq '.total'
# → 7
```

</details>

___

## 💻 5. Ressourcen verknüpfen

### Abfrage 5.1: Chaining – über eine Referenz hinweg filtern

„Alle C20-Diagnosen bei **Frauen**“ – das Geschlecht steht nicht in der Condition, sondern im verknüpften Patient:

```bash
curl -s "http://localhost:8080/fhir/Condition?code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|C20&subject:Patient.gender=female&_summary=count" | jq '.total'
# → 3
```

„Wie viele Diagnosen stammen aus **ambulanten** bzw. **stationären** Fällen?“ – die Fallart steht im verknüpften Encounter:

```bash
curl -s "http://localhost:8080/fhir/Condition?encounter:Encounter.class=AMB&_summary=count" | jq '.total'
# → 137
curl -s "http://localhost:8080/fhir/Condition?encounter:Encounter.class=IMP&_summary=count" | jq '.total'
# → 288
```

### Abfrage 5.2: Reverse Chaining (`_has`) – Patienten über ihre Daten finden

„Welche **Patienten** haben eine C20-Diagnose?“ – hier wird umgekehrt gesucht: Patienten, auf die eine passende Condition verweist:

```bash
curl -s "http://localhost:8080/fhir/Patient?_has:Condition:subject:code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|C20" \
  | jq '[.entry[].resource | {id: .id[0:20], gender, birthDate}]'
```

✅ **Erwartetes Ergebnis:** 5 Patienten (3 männlich, 2 weiblich).

`_has` lässt sich mit anderen Parametern kombinieren – z. B. Patienten mit **Pflegegrad 3** (OPS `9-984.8`):

```bash
curl -s "http://localhost:8080/fhir/Patient?_has:Procedure:subject:code=http://fhir.de/CodeSystem/bfarm/ops|9-984.8&_summary=count" | jq '.total'
# → 2
```

### Abfrage 5.3: `_include` – Befund mit allen Einzelwerten

Ein Laborbefund (`DiagnosticReport`) verweist über `result` auf seine Einzelwerte. Mit `_include` kommen diese in derselben Antwort mit:

```bash
curl -s "http://localhost:8080/fhir/DiagnosticReport?_id=REP-88ceb08a4e874daa01d5fab140f124a710a6218adfa22ae8de4a2620&_include=DiagnosticReport:result" \
  | jq '.entry[] | {modus: .search.mode, typ: .resource.resourceType, loinc: ([.resource.code.coding[] | select(.system == "http://loinc.org") | .code][0]), wert: .resource.valueQuantity.value, einheit: .resource.valueQuantity.unit}'
```

✅ **Erwartetes Ergebnis:** 1 Befund (`match`) und 9 Laborwerte (`include`) – eine **Blutgasanalyse** mit u. a. Kalium, Glukose, Laktat und Sauerstoffpartialdruck. Ein Wert hat keinen LOINC-Code (`loinc: null`) – siehe [Abfrage 4.1](#abfrage-41-hämoglobin--loinc-vs-lokaler-code).

### Abfrage 5.4: `_revinclude` – die Patientenakte

Mit `_revinclude` holst du alle Ressourcen, die **auf** einen Patienten verweisen – eine kleine Patientenakte in einer Abfrage:

```bash
PATIENT_ID=PID-5c07503c9075b5905cc9a256500bd9588e766e49176cce1f58a4f401

curl -s "http://localhost:8080/fhir/Patient?_id=$PATIENT_ID&_revinclude=Encounter:subject&_revinclude=Condition:subject&_revinclude=Procedure:subject&_revinclude=Observation:subject" \
  | jq '[.entry[].resource.resourceType] | group_by(.) | map({(.[0]): length}) | add'
```

✅ **Erwartetes Ergebnis:**

```json
{
  "Condition": 97,
  "Encounter": 4,
  "Observation": 8,
  "Patient": 1,
  "Procedure": 39
}
```

### 🛠️ Aufgabe: Patientenakte auswerten

- Welche **verschiedenen** Diagnosen hat dieser Patient? Tipp: `select(.resource.resourceType == "Condition")`, dann `unique`.
- Wie lange dauerten seine vier stationären Aufenthalte? Tipp: `Encounter?subject=Patient/$PATIENT_ID` und `.period`.

<details>
<summary>Lösung</summary>

```bash
curl -s "http://localhost:8080/fhir/Condition?subject=Patient/$PATIENT_ID&_count=200" \
  | jq '[.entry[].resource.code.coding[0].code] | unique'
# → 25 verschiedene Codes, u. a. C20, E11.90 (Diabetes Typ 2), I10.90 (Hypertonie)

curl -s "http://localhost:8080/fhir/Encounter?subject=Patient/$PATIENT_ID" \
  | jq '[.entry[].resource | {klasse: .class.code, von: .period.start[0:10], bis: .period.end[0:10]}] | sort_by(.von)'
# → 4 stationäre Aufenthalte (IMP) zwischen Februar 2023 und Mai 2024
```

</details>

___

## 🔍 6. Auffälligkeiten in den Daten

Echte DIZ-Daten sind nie perfekt. Mit FHIR-Search lassen sich Widersprüche aufspüren.

### Abfrage 6.1: Verstorben – oder doch nicht?

Der Vitalstatus wird im KDS doppelt abgebildet: als `deceased` im Patient und als eigene Observation (`67162-8`, Profil *Vitalstatus*) mit den Werten `L` (lebend) und `T` (tot):

```bash
# Patienten mit deceased = true
curl -s "http://localhost:8080/fhir/Patient?deceased=true&_summary=count" | jq '.total'
# → 260

# Vitalstatus-Observations mit "T" (tot)
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|67162-8&value-concept=https://www.medizininformatik-initiative.de/fhir/core/modul-person/CodeSystem/Vitalstatus|T&_summary=count" | jq '.total'
# → 1
```

❗ **Widerspruch:** 260 von 272 Patienten sind laut `Patient.deceased` verstorben, aber nur ein einziger Vitalstatus lautet „tot“ – alle 260 haben zugleich einen Vitalstatus „lebend“. Welche Angabe stimmt? Bei der Auswertung echter Daten muss so etwas mit dem Standort geklärt werden.

### Abfrage 6.2: Ein seltsamer Diagnosecode

```bash
curl -s "http://localhost:8080/fhir/Condition?code=570762" | jq '.entry[].resource | {code: .code.coding[0], patient: .subject.reference}'
```

❗ `570762` ist **kein gültiger ICD-10-GM-Code**. Solche Fehler fallen bei einer Suche nur auf, wenn man gezielt danach sucht. Systematisch finden sie erst der Terminologieserver ([Exercise 5](exercise-5.md)) und der Validator ([Exercise 6](exercise-6.md)).

___

## 💻 7. Skriptbasierter Ausblick (Python/R)

Für wiederkehrende Abfragen und statistische Auswertungen lohnt sich ein Skript. Bibliotheken übernehmen dabei das Blättern durch die Seiten und wandeln die Ressourcen in Tabellen um. Beide Beispiele holen alle Hämoglobin-Werte.

### 7.1 Python: fhir-pyrate

```bash
pip install fhir-pyrate
```

```python
from fhir_pyrate import Pirate

search = Pirate(auth=None, base_url="http://localhost:8080/fhir", print_request_url=True)

df = search.steal_bundles_to_dataframe(
    resource_type="Observation",
    request_params={"code": "http://loinc.org|718-7", "_count": 100},
    fhir_paths=[
        ("patient", "subject.reference"),
        ("datum", "effectiveDateTime"),
        ("wert", "valueQuantity.value"),
        ("einheit", "valueQuantity.unit"),
    ],
)

print(df.sort_values("datum").head())
print(df["wert"].describe())
```

### 7.2 R: fhircrackr

```r
# install.packages("fhircrackr")
library(fhircrackr)

request <- fhir_url(
  url = "http://localhost:8080/fhir",
  resource = "Observation",
  parameters = c(code = "http://loinc.org|718-7", "_count" = "100")
)
bundles <- fhir_search(request = request)

design <- fhir_table_description(
  resource = "Observation",
  cols = c(
    patient = "subject/reference",
    datum   = "effectiveDateTime",
    wert    = "valueQuantity/value",
    einheit = "valueQuantity/unit"
  )
)
df <- fhir_crack(bundles = bundles, design = design)

df$wert <- as.numeric(df$wert)
summary(df$wert)
```

> 💡 **Warum Skripte?**  
>
> - Automatisierung (regelmäßige Exporte, Cronjobs)  
> - Komplexität (mehrere Filterschritte, Aggregationen)  
> - Statistik (direkt in R/Python weiterarbeiten)  
> - Wiederverwendbarkeit (Versionierung im Git)

___

## 🏁 Zusammenfassung & Merkregeln

### Warum FHIR-Search?

> ✅ **Standardisiert** — Alle FHIR-Server sprechen dieselbe Sprache  
> ✅ **Standortübergreifend** — Dieselbe Abfrage funktioniert an jedem DIZ, sofern die Daten einheitlich kodiert sind  
> ✅ **Flexibel** — Filter, Verknüpfungen und Seiten lassen sich kombinieren  

### Wichtigste Parameter im Alltag

| Situation | Parameter | Beispiel |
| --------- | --------- | -------- |
| **Anzahl** | `_summary=count` | `Patient?_summary=count` |
| **Code-Suche** | `code` | `Condition?code=http://fhir.de/CodeSystem/bfarm/icd-10-gm\|C20` |
| **Werte filtern** | `value-quantity` | `Observation?code=http://loinc.org\|6298-4&value-quantity=gt5` |
| **Datum filtern** | `birthdate`, `date` | `Patient?birthdate=lt1950` |
| **Referenz-Suche** | `subject` | `Condition?subject=Patient/PID-...` |
| **Chaining** | `subject:Patient.gender` | `Condition?subject:Patient.gender=female` |
| **Reverse Chaining** | `_has` | `Patient?_has:Condition:subject:code=C20` |
| **Mitliefern** | `_include`, `_revinclude` | `Patient?_id=...&_revinclude=Condition:subject` |
| **Blättern** | `_count` + `next`-Link | `Patient?_count=5` |

### Was du über die Daten gelernt hast

- Die Patienten sind pseudonymisiert: keine Namen, gekürzte Geburtsdaten.
- Diagnosen und Laborwerte tragen oft nur Codes ohne Klartext.
- Über 40 % der Laborwerte haben nur einen lokalen Code und keinen LOINC-Code.
- Die Daten enthalten Widersprüche und ungültige Codes.

### Ausblick

- **Ex5:** Terminologieserver aufsetzen – Codes nachschlagen und prüfen  
- **Ex6:** FHIR Validator – Ressourcen gegen Profile und Terminologien prüfen  
- **Ex7:** Validierungsberichte interpretieren  

___
___
[Prerequisites](prerequisites.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • **Exercise 4** • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
___
___
