___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • **4 · Daten abfragen** • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___

# 🟠 Query von KDS-Daten

**Nächste Schritte:**  

- Prüfe, ob die Musterdaten aus Übung 3 im FHIR-Server liegen
- Erkunde Patienten, Diagnosen und Laborwerte mit FHIR-Search
- Verknüpfe Ressourcen über Chaining, `_has`, `_include` und `_revinclude`
- Entdecke Auffälligkeiten in den Daten

___

## Einführung & Kontext

In [Übung 3 · Musterdaten laden](exercise-3.md) haben wir die **Musterdatenspende** der Standorte UKSH, UKHD und UKW bereinigt und in den lokalen FHIR-Server (Blaze) geladen – rund 9.100 Ressourcen von 275 pseudonymisierten Patienten. Den Großteil davon liefert das UKSH.

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

> ⚠️ **Voraussetzung:** Blaze läuft auf `http://localhost:8080` (aus [Übung 2 · FHIR-Server starten](exercise-2.md#container-definieren-und-starten)) und die bereinigten Daten aller drei Standorte sind per `PUT` hochgeladen ([Übung 3 · Musterdaten laden](exercise-3.md)).

Zähle die Ressourcen pro Typ – `_summary=count` liefert nur die Anzahl, keine Ressourcen:

```bash
for type in Patient Encounter Condition Observation Procedure DiagnosticReport ServiceRequest Consent; do
  echo "$type: $(curl -s "http://localhost:8080/fhir/$type?_summary=count" | jq '.total')"
done
```

✅ **Erwartetes Ergebnis:**

```text
Patient: 275
Encounter: 1329
Condition: 482
Observation: 3636
Procedure: 205
DiagnosticReport: 1277
ServiceRequest: 1276
Consent: 84
```

> 💡 Deine Testressourcen aus [Übung 2 · FHIR-Server starten](exercise-2.md) liegen ebenfalls noch im Server und erhöhen einzelne Zahlen leicht: je hochgeladenem Beispiel-Patienten +1 bei `Patient`, die HbA1c-Observation +1 bei `Observation` und bei den Laborwerten.

___

## 📖 1. Hintergrund: Aufbau einer Suchanfrage

Eine FHIR-Suche hat immer die Form `GET [Basis-URL]/[Ressourcentyp]?[Parameter]=[Wert]&...`. Der Server antwortet mit einem `Bundle` vom Typ `searchset`.

| Parameter | Funktion | Beispiel |
| --------- | -------- | -------- |
| `_id` | Nach ID filtern | `Patient?_id=PID-...` |
| `_count` | Einträge pro Seite | `Patient?_count=5` |
| `_summary=count` | Nur Anzahl zurückgeben | `Condition?_summary=count` |
| `_elements` | Nur bestimmte Elemente zurückgeben | `Patient?_elements=gender,birthDate` |
| Token (`code`, `gender`, `class`, …) | Codes suchen, optional mit System: `system\|code` | `Condition?code=http://fhir.de/CodeSystem/bfarm/icd-10-gm\|R51` |
| Datum (`birthdate`, `date`, …) | Mit Präfixen `lt`, `le`, `gt`, `ge`, `eq` | `Patient?birthdate=lt1950` |
| Menge (`value-quantity`) | Zahlenwert mit Präfix, optional Einheit | `Observation?value-quantity=gt5` |
| Referenz (`subject`, `encounter`) | Auf andere Ressourcen verweisen | `Condition?subject=Patient/PID-...` |
| Chaining (`subject:Patient.gender`) | Über eine Referenz hinweg filtern | `Condition?subject:Patient.gender=female` |
| Reverse Chaining (`_has`) | Nach Ressourcen filtern, die auf mich verweisen | `Patient?_has:Condition:subject:code=R51` |
| `_include` / `_revinclude` | Verknüpfte Ressourcen mitliefern | `DiagnosticReport?_include=DiagnosticReport:result` |

> 💡 **Merke:** Mehrere Parameter werden mit **UND** verknüpft. Mehrere Werte im selben Parameter, durch Komma getrennt, bedeuten **ODER**: `code=R51,R11`.
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
# → 78

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

Alle Diagnosen der Musterdaten sind mit **ICD-10-GM** kodiert (`http://fhir.de/CodeSystem/bfarm/icd-10-gm`).

### Abfrage 3.1: Häufigste Diagnosen

Zum Auswerten holen wir alle 482 Diagnosen auf einer Seite und zählen die Codes mit `jq`:

```bash
curl -s "http://localhost:8080/fhir/Condition?_count=500" \
  | jq '[.entry[].resource.code.coding[0].code] | group_by(.) | map({code: .[0], anzahl: length}) | sort_by(-.anzahl) | .[0:8]'
```

✅ **Erwartetes Ergebnis (Auszug):**

| ICD-10-GM | Anzahl | Bedeutung |
| --------- | ------ | --------- |
| `Z11` | 27 | Spezielle Verfahren zur Untersuchung auf infektiöse und parasitäre Krankheiten |
| `C20` | 23 | Bösartige Neubildung des Rektums |
| `R51` | 22 | Kopfschmerz |
| `I45.2` | 19 | Bifaszikulärer Block |
| `R11` | 15 | Übelkeit und Erbrechen |
| `U99.0` | 15 | Spezielle Verfahren zur Untersuchung auf SARS-CoV-2 |

🔍 **Genau hinschauen:** Die Diagnosen enthalten nur den Code, **keinen Klartext** (`display`). Die Bedeutung musst du nachschlagen – zum Beispiel an einem Terminologieserver, wie du ihn in [Übung 5 · Codes prüfen](exercise-5.md) nutzt.

### Abfrage 3.2: Alle Kopfschmerz-Diagnosen (R51)

```bash
curl -s "http://localhost:8080/fhir/Condition?code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|R51&_count=50" \
  | jq '{diagnosen: .total, patienten: ([.entry[].resource.subject.reference] | unique | length)}'
```

✅ **Erwartetes Ergebnis:** `22` Diagnosen bei nur `5` Patienten.

💡 **Warum mehr Diagnosen als Patienten?** Eine Diagnose wird pro Fall (`Encounter`) dokumentiert. Wer mehrfach stationär behandelt wird, hat die gleiche Diagnose mehrfach.

___

## 💻 4. Laborwerte (LOINC)

Die Musterdaten enthalten 2.040 Laborwerte im KDS-Profil `ObservationLab`. Anders als das HbA1c-Beispiel aus [Übung 1 · Profil erstellen](exercise-1.md) sind hier z. B. Hämoglobin, Kalium und Natrium enthalten.

### Abfrage 4.1: Hämoglobin – LOINC vs. lokaler Code

Die Laborwerte des UKSH tragen einen **lokalen Laborcode** und – wenn vorhanden – zusätzlich einen **LOINC-Code**. UKHD und UKW kodieren ihre Laborwerte nur mit LOINC:

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
# → 2040
curl -s "http://localhost:8080/fhir/Observation?category=laboratory&code=http://medic.uksh.de/Codeystem/unknown|Unknown&_summary=count" | jq '.total'
# → 819
```

🔍 **Genau hinschauen:** 819 von 2.040 Laborwerten (rund 40 %) haben **keinen LOINC-Code**, sondern nur einen lokalen Code. Eine standortübergreifende Abfrage per LOINC findet diese Werte nicht. Das Mapping lokaler Codes auf LOINC ist eine zentrale Aufgabe im DIZ.

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

Welcher Patient ist das?
```bash
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|718-7&value-quantity=lt10" \
  | jq '{patienten: ([.entry[].resource.subject.reference] | unique)}'
# → Patient/<PID>
```

</details>

___

## 💻 5. Ressourcen verknüpfen

### Abfrage 5.1: Chaining – über eine Referenz hinweg filtern

„Alle R51-Diagnosen bei **Frauen**“ – das Geschlecht steht nicht in der Condition, sondern im verknüpften Patient:

```bash
curl -s "http://localhost:8080/fhir/Condition?code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|R51&subject:Patient.gender=female&_summary=count" | jq '.total'
# → 13
```

„Wie viele Diagnosen stammen aus **ambulanten** bzw. **stationären** Fällen?“ – die Fallart steht im verknüpften Encounter:

```bash
curl -s "http://localhost:8080/fhir/Condition?encounter:Encounter.class=AMB&_summary=count" | jq '.total'
# → 144
curl -s "http://localhost:8080/fhir/Condition?encounter:Encounter.class=IMP&_summary=count" | jq '.total'
# → 315
```

### Abfrage 5.2: Reverse Chaining (`_has`) – Patienten über ihre Daten finden

„Welche **Patienten** haben eine R51-Diagnose?“ – hier wird umgekehrt gesucht: Patienten, auf die eine passende Condition verweist:

```bash
curl -s "http://localhost:8080/fhir/Patient?_has:Condition:subject:code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|R51" \
  | jq '[.entry[].resource | {id, gender, birthDate}]'
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

Mit `_revinclude` holst du alle Ressourcen, die **auf** einen Patienten verweisen – eine kleine Patientenakte in einer Abfrage. Wähle dafür einen der Patienten mit R51-Diagnose aus [Abfrage 5.2](#abfrage-52-reverse-chaining-_has--patienten-über-ihre-daten-finden) und speichere seine ID in einer Variablen:

```bash
curl -s "http://localhost:8080/fhir/Patient?_has:Condition:subject:code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|R51" \
  | jq -r '.entry[].resource.id'

# Eine der ausgegebenen IDs einsetzen:
PATIENT_ID=<ID>

curl -s "http://localhost:8080/fhir/Patient?_id=$PATIENT_ID&_revinclude=Encounter:subject&_revinclude=Condition:subject&_revinclude=Procedure:subject&_revinclude=Observation:subject" \
  | jq '[.entry[].resource.resourceType] | group_by(.) | map({(.[0]): length}) | add'
```

### 🛠️ Aufgabe: Patientenakte auswerten

- Welche **verschiedenen** Diagnosen hat dieser Patient? Tipp: `select(.resource.resourceType == "Condition")`, dann `unique`.
- Wie viele stationäre Aufenthalte (`class` = `IMP`) hatte er, und wie lange dauerten sie? Tipp: `Encounter?subject=Patient/$PATIENT_ID` und `.period`.

<details>
<summary>Lösung</summary>

```bash
curl -s "http://localhost:8080/fhir/Condition?subject=Patient/$PATIENT_ID&_count=200" \
  | jq '[.entry[].resource.code.coding[0].code] | unique'

curl -s "http://localhost:8080/fhir/Encounter?subject=Patient/$PATIENT_ID" \
  | jq '[.entry[].resource | {klasse: .class.code, von: .period.start[0:10], bis: .period.end[0:10]}] | sort_by(.von)'
```

</details>

___

## 🔍 6. Auffälligkeiten in den Daten

Echte Routinedaten sind nie perfekt. Mit FHIR-Search lassen sich Widersprüche aufspüren.

### Abfrage 6.1: Verstorben – oder doch nicht?

Der Vitalstatus wird im KDS doppelt abgebildet: als `deceased[x]` im Patient und als eigene Observation (`67162-8`, Profil *Vitalstatus*) mit den Werten `L` (lebend) und `T` (tot). Wir zählen beide Angaben getrennt:

```bash
# Patienten mit deceased = true
curl -s "http://localhost:8080/fhir/Patient?deceased=true&_summary=count" | jq '.total'
# → 259

# Vitalstatus-Observations mit "T" (tot)
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|67162-8&value-concept=https://www.medizininformatik-initiative.de/fhir/core/modul-person/CodeSystem/Vitalstatus|T&_summary=count" | jq '.total'
# → 1

# Vitalstatus-Observations mit "L" (lebend)
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|67162-8&value-concept=https://www.medizininformatik-initiative.de/fhir/core/modul-person/CodeSystem/Vitalstatus|L&_summary=count" | jq '.total'
# → 1582
```

❗ **Auffälligkeit:** Laut `Patient.deceased` sind 259 von 275 Patienten verstorben, aber nur eine einzige Observation meldet den Vitalstatus „tot“. Ist das ein Widerspruch?

💡 **Nicht zwingend, denn beide Angaben haben einen anderen Zeitbezug:**

- `Patient.deceased[x]` beschreibt den **aktuellen** Stand, bei `deceasedDateTime` samt Todeszeitpunkt.
- Die Vitalstatus-Observation ist eine **Momentaufnahme**: „Zum Zeitpunkt `effective[x]` war der Patient lebend (bzw. tot).“

Ein Patient, der 2023 bei einem Aufenthalt mit „L“ dokumentiert wurde und 2025 verstorben ist, hat beide Angaben zu Recht. Ein **echter** Widerspruch liegt erst vor, wenn eine „L“-Observation **nach** dem Todesdatum des Patienten datiert ist.

Das prüfen wir, indem wir die Observations samt zugehörigem Patient laden und die Datumsangaben vergleichen:

```bash
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|67162-8&_include=Observation:subject&_count=2000" | jq '
  [.entry[].resource] as $r
  | ($r | map(select(.resourceType=="Patient"))
        | map({key: ("Patient/" + .id), value: .deceasedDateTime})
        | from_entries) as $tod
  | [$r[] | select(.resourceType=="Observation")
      | {patient: .subject.reference,
         status: .valueCodeableConcept.coding[0].code,
         datum: .effectiveDateTime,
         verstorben: $tod[.subject.reference]}]
  | map(select(.status=="L" and .verstorben != null and .datum > .verstorben))
  | {echte_widersprueche: length, beispiele: .[0:3]}'
# → 0
```

⚠️ **Einschränkungen der Prüfung:**

- Der Vergleich `.datum > .verstorben` ist ein reiner Textvergleich. Er ist zuverlässig, solange beide Werte dasselbe Format haben, kann bei gemischten Formaten (`2025-03-01` vs. `2025-03-01T10:00:00+01:00`) aber ungenau sein.
- Patienten mit `deceasedBoolean = true` ohne Datum lassen sich so nicht prüfen. Sie fallen aus dem Filter heraus.
- `_count=2000` holt alle rund 1.600 Vitalstatus-Observations auf einer Seite (Blaze erlaubt bis zu 10.000). Bei größeren Datenmengen gibt es weitere Seiten, erkennbar an einem `next`-Link unter `jq '.link'`.

**Was du mitnehmen sollst:** Jede Angabe im KDS hat einen Zeitbezug. Zwei Angaben, die auf den ersten Blick nicht zusammenpassen, sind erst dann ein Widerspruch, wenn sich dieselbe Aussage zum selben Zeitpunkt unterscheidet.

### Abfrage 6.2: Ein seltsamer Diagnosecode

```bash
curl -s "http://localhost:8080/fhir/Condition?code=570762" | jq '.entry[].resource | {code: .code.coding[0], patient: .subject.reference}'
```

❗ `570762` ist **kein gültiger ICD-10-GM-Code**. Solche Fehler fallen bei einer Suche nur auf, wenn man gezielt danach sucht. Systematisch finden sie erst der Terminologieserver ([Übung 5 · Codes prüfen](exercise-5.md)) und der Validator ([Übung 6 · Ressourcen validieren](exercise-6.md)).

___

## 💻 7. Skriptbasierter Ausblick (Python/R)

Für wiederkehrende Abfragen und statistische Auswertungen lohnt sich ein Skript. Bibliotheken übernehmen dabei das Blättern durch die Seiten und wandeln die Ressourcen in Tabellen um. Beide Beispiele holen alle Hämoglobin-Werte.

### 7.1 Python: fhir-pyrate

```bash
pip install fhir-pyrate
```

> 💡 Neuere Ubuntu-/Debian-Versionen (auch unter WSL2) verweigern `pip install` außerhalb einer virtuellen Umgebung mit dem Fehler `externally-managed-environment`. Lege dann vorher eine an:
>
> ```bash
> python3 -m venv ~/venv-fhir && source ~/venv-fhir/bin/activate
> ```

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
| **Code-Suche** | `code` | `Condition?code=http://fhir.de/CodeSystem/bfarm/icd-10-gm\|R51` |
| **Werte filtern** | `value-quantity` | `Observation?code=http://loinc.org\|6298-4&value-quantity=gt5` |
| **Datum filtern** | `birthdate`, `date` | `Patient?birthdate=lt1950` |
| **Referenz-Suche** | `subject` | `Condition?subject=Patient/PID-...` |
| **Chaining** | `subject:Patient.gender` | `Condition?subject:Patient.gender=female` |
| **Reverse Chaining** | `_has` | `Patient?_has:Condition:subject:code=R51` |
| **Mitliefern** | `_include`, `_revinclude` | `Patient?_id=...&_revinclude=Condition:subject` |
| **Blättern** | `_count` + `next`-Link | `Patient?_count=5` |

### Was du über die Daten gelernt hast

- Die Patienten sind pseudonymisiert: keine Namen, gekürzte Geburtsdaten.
- Diagnosen und Laborwerte tragen oft nur Codes ohne Klartext.
- Rund 40 % der Laborwerte haben nur einen lokalen Code und keinen LOINC-Code.
- Die Daten enthalten Widersprüche und ungültige Codes.

### Ausblick

- **Übung 5:** Terminologien prüfen mit FHIR-Operationen – Codes nachschlagen und prüfen  
- **Übung 6:** Terminologieserver einrichten und mit dem FHIR Validator Ressourcen gegen Profile prüfen  
- **Übung 7:** Validierungsberichte interpretieren  

___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • **4 · Daten abfragen** • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___
