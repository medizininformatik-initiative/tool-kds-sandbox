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

Dabei gehst du so vor, wie man sich unbekannten Daten nähern kann:

1. **Überblick:** Was gibt es, wie oft? (z. B. alle Codes zählen)
2. **Stelle finden:** Was fällt auf? Welche Ressourcen sind betroffen? (IDs anzeigen lassen)
3. **Nachsehen:** Die betroffene Ressource oder das Feld ansehen und einordnen.

> 💡 **Warum FHIR-Search?**  
> FHIR-Search dient als standardisierte API-Schnittstelle zu FHIR-Datenrepositorien. Dadurch wird ein standortübergreifend einheitlicher Zugriff auf die im DIZ integrierten Daten möglich.

> 💡 **Ausblick: TORCH & DIMP/DUP**  
> Für komplexe Datenanforderungen (z. B. kohortenbasierte Extraktion mit Consent-Check) gibt es im MII-Ökosystem spezialisierte Tools:
>
> - **[TORCH](https://github.com/medizininformatik-initiative/torch)**: Ein FHIR®-Extraction-Tool für strukturierte, consent-konforme Datenextraktion. TORCH-Ausleitungen werden als **CRTDL** (Clinical Resource Transfer Definition Language) definiert und können entweder CQL oder FLARE für die Abfrage der Kohorte im FHIR-Server verwenden. Ziel: Batch-Extraktion für Forschungsanfragen inkl. MII-Consent-Handling.
> - **DIMP/DUP-Pipeline (aether-orchestriert)**: DUP = Data Usage Project / Forschungsprojekte erfordern eine Vereinheitlichung bei Extraktion sowie De-Identifikation, Maskierung und Pseudonymisierung (kurz DIMP) der bereitzustellenden Daten. Die Ausleitung wird bei Verwendung von TORCH mittels aether orchestriert.
>
> Diese Tools sind **nicht Bestandteil dieser praktischen Übung**, aber es ist wichtig zu wissen, dass sie im DIZ-Alltag für large-scale oder consent-komplexe Datenanfragen eingesetzt werden. TORCH ersetzt nicht FHIR-Search, sondern erweitert es um projektbasierte, auditierbare Extraktionsketten.

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

✅ **Erwartetes Mindest-Ergebnis:**

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
> ⚠️ **Server-Unterschiede:** Nicht jeder FHIR-Server unterstützt jeden Parameter. Was ein Server kann, steht in seinem `CapabilityStatement` (`/fhir/metadata`).

___

## 💻 2. Patienten erkunden

### Abfrage 2.1: Woher stammen die Patienten?

Bevor du dir einzelne Patienten ansiehst, verschaffst du dir einen Überblick. Jeder Patient trägt einen `identifier`, sein System verrät, wie der Standort seine Patienten kennzeichnet. `jq -r` gibt das System jedes Patienten als eine Zeile aus, `sort | uniq -c` zählt gleiche Zeilen:

```bash
curl -s "http://localhost:8080/fhir/Patient?_count=300" \
  | jq -r '.entry[].resource.identifier[0].system' | sort | uniq -c
```

✅ **Erwartetes Ergebnis:**

```text
    272 https://www.medizininformatik-initiative.de/fhir/sid/pseudonym
      3 urn:oid:1.2.276.0.76.3.1.78.1.1.10.60.1.2
```

Einen Standort-Eintrag haben die Ressourcen nicht durchgängig. Jeder Standort vergibt seine IDs aber nach einem eigenen Muster. Daran erkennst du in den folgenden Übungen, woher eine Ressource stammt:

| Standort | Patient | Encounter | Patienten |
| --- | --- | --- | --- |
| UKSH | `PID-013b68fc…` | `PV-70cdf2f6…` | 271 |
| UKHD | `0002690836` (nur Ziffern) | `0061845260-e` | 3 |
| UKW | `Patient-54211` | `Encounter-8163579` | 1 |

Sieh dir je einen Patienten des UKSH und des UKHD an. `del(.meta)` blendet die Verwaltungsdaten aus:

```bash
curl -s "http://localhost:8080/fhir/Patient/PID-013b68fc80dc51ce452717eb1647c91c9f26c8008755988e6baa0045" | jq 'del(.meta)'
curl -s "http://localhost:8080/fhir/Patient/0001736293" | jq 'del(.meta)'
```

✅ **Erwartetes Ergebnis** (gekürzt):

```text
UKSH-Identifier: Patient-Ressource mit Identifier nach System …/sid/pseudonym, "gender": "female", "birthDate": "2000-12", "deceasedBoolean": true
UKHD-Identifier: Patient-Ressource mit Identifier vom Typ MR mit System urn:oid:…, "birthDate": "1979-06-03", "gender": "female",
      address mit "valueCode": "MASKED", "deceasedBoolean": false
```

🧩 **Was du gerade gesehen hast:**

- Die UKSH-Patienten sind **pseudonymisiert**: Statt eines Namens gibt es nur ein Pseudonym, das Geburtsdatum ist auf Jahr und Monat gekürzt.
- Der UKHD-Patient trägt einen `identifier` vom Typ `MR` (Patientennummer) mit einem OID-System und ein vollständiges Geburtsdatum. Die Adresse ist vorhanden, ihr Inhalt aber per `data-absent-reason` als `MASKED` ausgeblendet.
- Die beiden Standorte setzen Pseudonymisierung und Datensparsamkeit also unterschiedlich um. Bevor du Daten mehrerer Standorte gemeinsam auswertest, lohnt sich deshalb ein vergleichender Blick auf den Datenbestand.

### Abfrage 2.2: Patienten nach Geschlecht und Alter

Auch hier zuerst der Überblick über alle Werte (Abfrage von bis zu 300 Patienten, gezählt wird in der Antwort des Servers):

```bash
curl -s "http://localhost:8080/fhir/Patient?_count=300" \
  | jq -r '.entry[].resource.gender' | sort | uniq -c
```

✅ **Erwartetes Ergebnis:**

```text
     78 female
    169 male
     25 null
      3 unknown
```

Mit FHIR-Search zählst du dieselben Gruppen direkt am Server:

```bash
# Weibliche Patienten
curl -s "http://localhost:8080/fhir/Patient?gender=female&_summary=count" | jq '.total'
# → 78

# Vor 1950 geboren
curl -s "http://localhost:8080/fhir/Patient?birthdate=lt1950&_summary=count" | jq '.total'
# → 23
```

Wer sind die 25 Patienten ohne Geschlecht? Zähle sie nach den ersten drei Zeichen ihrer ID, also nach Standort (siehe Tabelle in 2.1), und lass dir dann die IDs der UKSH-Patienten anzeigen:

```bash
curl -s "http://localhost:8080/fhir/Patient?_count=300" \
  | jq -r '.entry[].resource | select(.gender == null) | .id[0:3]' | sort | uniq -c

curl -s "http://localhost:8080/fhir/Patient?_count=300" \
  | jq -r '.entry[].resource | select(.gender == null) | .id' | grep '^PID' | head -3
```

✅ **Erwartetes Ergebnis:** Mind. 25 IDs beginnend mit `PID`, dazu Zeilen für deine Testpatienten aus Übung 2 (z. B. `exa`). Die IDs beginnen mit `PID-0507e0bc…`, `PID-0bb96ecc…`, `PID-1229b355…`. Rufst du einen davon wie in 2.1 ab, fehlt das Element `gender` einfach:

```bash
curl -s "http://localhost:8080/fhir/Patient/PID-0507e0bcc3212f8c64727a6f586c9a689a733099d858855256cab915" | jq 'del(.meta)'
```

🧩 **Was du gerade gesehen hast:** Der Überblick zeigt auch, was **fehlt**. Eine Suche wie `gender=female` oder `gender=male` findet diese 25 Patienten nicht. Zählst du Frauen und Männer zusammen, kommst du deshalb nicht auf alle Patienten.

### Abfrage 2.3: Blättern durch Ergebnisse (Pagination)

Große Ergebnismengen liefert der Server seitenweise. Die Gesamtzahl steht in `total`, die nächste Seite als Link mit `relation: "next"` im Bundle:

```bash
# Erste Seite mit 5 Patienten: Gesamtzahl und IDs dieser Seite
curl -s "http://localhost:8080/fhir/Patient?_count=5" | jq -r '.total, .entry[].resource.id[0:20]'

# Die Links des Bundles: first (erste Seite), self (diese Anfrage) und next (nächste Seite)
curl -s "http://localhost:8080/fhir/Patient?_count=5" | jq -r '.link[] | "\(.relation)  \(.url)"'

# Nächste Seite abrufen: <next-URL> im folgenden Befehl durch den "next"-Link aus der vorherigen Ausgabe ersetzen
curl -s "<next-URL>" | jq -r '.entry[].resource.id[0:20]'
```

> 💡 **Merke:** `total` ist die Gesamtanzahl der Treffer, `entry` enthält nur die Ressourcen der aktuellen Seite. Für die Überblicke in dieser Übung holen wir deshalb mit einer geeigneten Wahl des Werts für `_count` alle Treffer auf eine Seite.

___

## 💻 3. Diagnosen (ICD-10-GM)

Alle Diagnosen der Musterdaten sind mit **ICD-10-GM** kodiert (`http://fhir.de/CodeSystem/bfarm/icd-10-gm`).

### Abfrage 3.1: Häufigste Diagnosen

Zum Überblick holen wir alle 482 Diagnosen auf einer Seite und zählen die Codes:

```bash
curl -s "http://localhost:8080/fhir/Condition?_count=500" \
  | jq -r '.entry[].resource.code.coding[0].code' | sort | uniq -c | sort -rn | head -8
```

✅ **Erwartetes Ergebnis:**

```text
     27 Z11
     23 C20
     22 R51
     19 I45.2
     15 U99.0
     15 R11
      9 R52.0
      9 I10.90
```

| ICD-10-GM | Bedeutung |
| --------- | --------- |
| `Z11` | Spezielle Verfahren zur Untersuchung auf infektiöse und parasitäre Krankheiten |
| `C20` | Bösartige Neubildung des Rektums |
| `R51` | Kopfschmerz |
| `I45.2` | Bifaszikulärer Block |
| `U99.0` | Spezielle Verfahren zur Untersuchung auf SARS-CoV-2 |
| `R11` | Übelkeit und Erbrechen |

🧩 **Was du gerade gesehen hast:** Die Diagnosen enthalten nur den Code, **keinen Klartext** (`display`). Die Bedeutung musst du nachschlagen, zum Beispiel an einem Terminologieserver, wie du ihn in [Übung 5 · Codes prüfen](exercise-5.md) nutzt.

> 💡 Das Zählen erledigt hier `jq` auf deinem Rechner, nicht der Server. Die FHIR-Suche kann Ressourcen filtern, aber nicht gruppieren oder pro Wert zählen. Soll der Server solche Auswertungen selbst liefern, brauchst du **[CQL](https://cql.hl7.org/)** (Clinical Quality Language): Die Logik steht in einer `Library`, eine `Measure` legt fest, wonach gezählt wird, und `$evaluate-measure` liefert das Ergebnis als `MeasureReport`. Bspw. der Blaze-FHIR-Server unterstützt das ([CQL-Abfragen in Blaze](https://blaze-server.org/cql-queries.html)).

### Abfrage 3.2: Kopfschmerz-Diagnosen (R51) genauer ansehen

`R51` steht 22-mal in den Daten. Von wie vielen Patienten stammen diese Diagnosen?

```bash
curl -s "http://localhost:8080/fhir/Condition?code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|R51&_count=50" \
  | jq -r '.entry[].resource.subject.reference' | sort | uniq -c
```

✅ **Erwartetes Ergebnis:**

```text
      1 Patient/0002690836
      1 Patient/PID-4f1c98e0[...]
      7 Patient/PID-5c07503c[...]
      6 Patient/PID-732cc339[...]
      7 Patient/PID-e5d803e4[...]
```

22 Diagnosen verteilen sich auf nur 5 Patienten, drei davon haben sie sechs- oder siebenmal. Sieh dir die Diagnosen eines dieser Patienten an: wann sie dokumentiert wurden und zu welchem Fall (`encounter`) sie gehören:

```bash
curl -s -G "http://localhost:8080/fhir/Condition" \
  --data-urlencode "code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|R51" \
  --data-urlencode "subject=Patient/PID-e5d803e49c59d57d9d3df687dd7993c14438d633d6a7369054a7ff7f" \
  | jq -r '.entry[].resource | "\(.recordedDate[0:16])  \(.encounter.reference[0:22])  \(.id[0:16])"' | sort
```

✅ **Erwartetes Ergebnis:**

```text
2024-01-18T10:13  Encounter/PV-aa045b62a[...]  CON-a727b252d6aa[...]
2024-02-12T13:52  Encounter/PV-561c40aa3[...]  CON-ff189f4ce89f[...]
2024-02-12T13:56  Encounter/PV-561c40aa3[...]  CON-33c6903dd496[...]
2024-02-12T13:56  Encounter/PV-561c40aa3[...]  CON-50173814fec9[...]
2024-02-12T13:56  Encounter/PV-561c40aa3[...]  CON-59f90548f316[...]
2024-02-12T13:56  Encounter/PV-561c40aa3[...]  CON-76231e6563c6[...]
2024-02-23T12:04  Encounter/PV-ac641aa86[...]  CON-b81e2a51f78e[...]
```

🧩 **Was du gerade gesehen hast:**

- Fünf der sieben Diagnosen gehören zum **selben Fall** und wurden innerhalb von vier Minuten dokumentiert. Jede ist eine eigene `Condition` mit eigener ID.
- Für die Auswertung heißt das: Die Anzahl der Condition-Ressourcen ist nicht die Anzahl der Erkrankten oder der Fälle.
- Ob die Mehrfachdokumentation im Klinikum so entsteht oder erst bei der Umwandlung nach FHIR, siehst du den Daten nicht an. Das wäre eine Frage an den Standort.

### Abfrage 3.3: Ungewöhnliche Codes finden

Die Codes in den Musterdaten haben fast alle dieselbe Form: ein Buchstabe, zwei Ziffern, optional ein Punkt mit weiteren Ziffern (`R51`, `I45.2`, `R52.0`). `grep -vE` zeigt alle Codes, die **nicht** in dieses Muster passen:

```bash
curl -s "http://localhost:8080/fhir/Condition?_count=500" \
  | jq -r '.entry[].resource.code.coding[0].code' \
  | grep -vE '^[A-Z][0-9]{2}(\.[0-9]+)?$' | sort | uniq -c
```

✅ **Erwartetes Ergebnis:**

```text
      1 570762
      2 Z11 U99.0!
```

Zu welchen Diagnosen gehören diese Codes? Die Suche liefert dir die IDs und die Patienten. `--data-urlencode` kümmert sich um das Leerzeichen und das `!` im zweiten Code:

```bash
curl -s "http://localhost:8080/fhir/Condition?code=570762" \
  | jq -r '.entry[].resource | "\(.id)  \(.subject.reference[0:20])"'

curl -s -G "http://localhost:8080/fhir/Condition" --data-urlencode "code=Z11 U99.0!" \
  | jq -r '.entry[].resource | "\(.id)  \(.subject.reference[0:20])"'
```

✅ **Erwartetes Ergebnis:** eine UKSH-Diagnose mit `570762` (`CON-6c7f7081…`, `Patient/PID-b3726941`) und die beiden UKW-Diagnosen `Diagnosis-010` und `Diagnosis-026` (`Patient/Patient-54211`). Mit der ID siehst du dir die Ressource selbst an:

```bash
curl -s "http://localhost:8080/fhir/Condition/Diagnosis-010" | jq '.code'
```

🧩 **Was du gerade gesehen hast:**

- Es ist der Code `570762` hinterlegt. Dieser ist **kein ICD-10-GM-Code**, dafür hat er nicht die richtige Form.
- `Z11 U99.0!` sind **zwei** Codes in **einem** Feld. In einem `Coding` darf aber nur ein Code stehen.
- Unter 482 Diagnosen fallen solche Einzelfälle in der Liste aus 3.1 nicht auf. Mit einem einfachen Muster findest du sie, auch ohne aufwändigere Validierung, schnell. Ob ein Code mit der richtigen Form auch existiert, prüft das Muster aber nicht. Das prüfen ein Terminologieserver ([Übung 5 · Codes prüfen](exercise-5.md)) und der Validator ([Übung 6 · Ressourcen validieren](exercise-6.md)). Dort begegnen dir beide Diagnosen wieder.

___

## 💻 4. Laborwerte (LOINC)

Die Musterdaten enthalten 2.040 Laborwerte im KDS-Profil `ObservationLab`. Wir hatten dazu aus [Übung 1 · Profil erstellen](exercise-1.md) das HbA1c-Beispiel. Durch die Musterdaten liegen uns nun unter anderem auch Angaben zu Hämoglobin, Kalium und Natrium vor.

### Abfrage 4.1: Überblick – von wem stammen die Laborwerte?

```bash
curl -s "http://localhost:8080/fhir/Observation?category=laboratory&_count=2100" \
  | jq -r '.entry[].resource.subject.reference' | sort | uniq -c | sort -rn
```

✅ **Erwartetes Ergebnis** (deine HbA1c-Observation aus Übung 2 kommt als `Patient/example-patient` dazu):

```text
   1720 Patient/PID-6f82e92c1857529e36717bdf6aefedd54da8d1b82ab9e8532fecb1d6
    159 Patient/PID-62849a39033ea35eb90174f6d272553979d88999c88525833d4c455d
    151 Patient/Patient-54211
      7 Patient/PID-6aa4992801998f580de917b3fd829b93520162e194531790620c0efe
      2 Patient/example-patient
      2 Patient/PID-32bfa61f37f53387a76f69162ea85f0c920eb3b998240f979e696e04
      1 Patient/0002690836
```

🧩 **Was du gerade gesehen hast:** Laborwerte gibt es nur für 6 der Muster-Patienten, und fast alle (> 80 %) stammen von einer einzigen Person. Eine Statistik über „die Laborwerte“ der Musterdaten beschreibt also im Wesentlichen einen Patienten. Vor einer Auswertung kann ein Blick auf die Verteilung der Referenzen solche Schieflagen aufzeigen.

### Abfrage 4.2: Hämoglobin – LOINC und lokale Codes

Die Laborwerte des UKSH tragen einen **lokalen Laborcode** und, wenn vorhanden, zusätzlich einen **LOINC-Code**. Welche Codes stehen bei den Hämoglobin-Werten (LOINC `718-7`)?

```bash
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|718-7&_count=50" \
  | jq -r '.entry[].resource.code.coding[] | "\(.system)  \(.code)"' | sort | uniq -c
```

✅ **Erwartetes Ergebnis:**

```text
     32 http://loinc.org  718-7
      1 http://medic.uksh.de/fhir/CodeSystem/Laborparameter  LAB_hb6po
     31 http://medic.uksh.de/fhir/CodeSystem/Laborparameter  LAB_hbe
```

🧩 **Was du gerade gesehen hast:** Hinter einem LOINC-Code stecken hier zwei lokale Codes. Eine Suche über LOINC findet alle 32 Werte, eine Suche über den lokalen Code `LAB_hbe` nur 31. Wer über lokale Codes sucht, muss alle passenden Hauscodes kennen. LOINC fasst sie hier zusammen.

Wie viele Laborwerte haben überhaupt einen LOINC-Code? Zähle wie oben die Codesysteme, diesmal über alle Laborwerte:

```bash
curl -s "http://localhost:8080/fhir/Observation?category=laboratory&_count=2100" \
  | jq -r '.entry[].resource.code.coding[].system' | sort | uniq -c | sort -rn
```

✅ **Erwartetes Ergebnis** (deine HbA1c-Observation aus Übung 2 erhöht LOINC um 1):

```text
   1888 http://medic.uksh.de/fhir/CodeSystem/Laborparameter
   1221 http://loinc.org
    819 http://medic.uksh.de/Codeystem/unknown
```

Das dritte System fällt auf. Sieh dir einen Laborwert damit an:

```bash
curl -s "http://localhost:8080/fhir/Observation?code=http://medic.uksh.de/Codeystem/unknown|Unknown&_count=1" \
  | jq '.entry[0].resource.code'
```

✅ **Erwartetes Ergebnis** (der lokale Code kann abweichen):

```json
{
  "coding": [
    { "system": "http://medic.uksh.de/fhir/CodeSystem/Laborparameter", "code": "LAB_tpsu" },
    { "system": "http://medic.uksh.de/Codeystem/unknown", "code": "Unknown" }
  ]
}
```

🧩 **Was du gerade gesehen hast:**

- 819 von 2.040 Laborwerten (rund 40 %) haben statt eines LOINC-Codes einen **Platzhalter**: das „Codesystem“ `…/Codeystem/unknown` (mit `Codeystem` statt `CodeSystem` in der URL) und den Code `Unknown`. Die Werte gehen dadurch nicht verloren, sie wären aber über LOINC (z. B. bei einer standortübergreifenden Anfrage) nicht auffindbar.
- Das Mapping lokaler Codes auf LOINC ist eine zentrale Aufgabe im DIZ, um die Daten einheitlich abfragbar zu machen.

### Abfrage 4.3: Auffällige Werte finden – Kalium

Kalium (`6298-4`) über 5 mmol/L. Die Ausgabe zeigt je Wert eine Zeile mit Datum, Wert, Bewertung (`H` = hoch) und ID. `sort` sortiert nach Datum, denn Blaze kann mit `_sort` nicht nach Datum sortieren:

```bash
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|6298-4&value-quantity=gt5|http://unitsofmeasure.org|mmol/L" \
  | jq -r '.entry[].resource | "\(.effectiveDateTime[0:16])  \(.valueQuantity.value) \(.valueQuantity.unit)  \(.interpretation[0].coding[0].code)  \(.id)"' | sort
```

✅ **Erwartetes Ergebnis:**

```text
2022-01-21T17:23  5.7 mmol/l  H  LAB-85ecf41049e5546ea6dc9d49bc89e21790175d3a06c1997da0379a38
2022-01-22T16:06  5.8 mmol/l  H  LAB-913341b4ce6b825fabeab60eb9b25421e4ddd6c609f1f514e7119841
2022-01-22T16:06  7.2 mmol/l  H  LAB-a980ce5c99349ed87a79351a32f93b2165968564ea91d80988c6c042
2022-02-04T17:06  8.8 mmol/l  H  LAB-fa39d35917e47c1e366944975d3ae03005cc30bb9822b4972403b67f
2022-02-04T17:10  6.6 mmol/l  H  LAB-1c0f057b3e1bb6028f4cf74ff2ce5db54c7320425c626e63e679e472
```

> 💡 **Merke:** Bei `value-quantity` steht die Einheit als UCUM-Code hinter dem Wert: `[präfix][wert]|[system]|[code]`. Ohne Filterung (`gt5`) würde einfach nur der Wert abgefragt.

Alle fünf Werte stammen vom selben Patienten (`PID-62849a39…`). Ein Filter zeigt dir nur die Werte, die ihn erfüllen. Wie sah es davor und danach aus? Hol dir alle Kaliumwerte dieses Patienten aus den ersten drei Tagen. Zwei `date`-Parameter grenzen den Zeitraum ein:

```bash
curl -s -G "http://localhost:8080/fhir/Observation" \
  --data-urlencode "code=http://loinc.org|6298-4" \
  --data-urlencode "subject=Patient/PID-62849a39033ea35eb90174f6d272553979d88999c88525833d4c455d" \
  --data-urlencode "date=ge2022-01-21" \
  --data-urlencode "date=lt2022-01-24" \
  | jq -r '.entry[].resource | "\(.effectiveDateTime[0:16])  \(.valueQuantity.value) \(.valueQuantity.unit)  \(.interpretation[0].coding[0].code)"' | sort
```

✅ **Erwartetes Ergebnis:**

```text
2022-01-21T17:21  4.2 mmol/l  N
2022-01-21T17:23  5.7 mmol/l  H
2022-01-21T17:29  3.4 mmol/l  N
2022-01-22T16:03  3.7 mmol/l  N
2022-01-22T16:06  5.8 mmol/l  H
2022-01-22T16:06  7.2 mmol/l  H
2022-01-22T16:09  3.7 mmol/l  N
2022-01-23T13:59  4.5 mmol/l  N
2022-01-23T14:03  4.9 mmol/l  H
```

🧩 **Was du gerade gesehen hast:** Die hohen Werte stehen jeweils zwischen normalen Werten, die wenige Minuten vorher oder nachher gemessen wurden. Ein einzelner Wert mit `H` ist nicht genug für einen Befund. Der Filter findet Kandidaten, der Verlauf hilft, sie einzuordnen. Den Befund, zu dem der höchste Wert (8.8) gehört, siehst du dir in [Abfrage 5.3](#abfrage-53-_include--befund-mit-allen-einzelwerten) an.

### 💻 Dasselbe für Hämoglobin und Natrium

Mit demselben Muster findest du Hämoglobin-Werte unter 10 g/dL und Natrium-Werte (`2951-2`) unter 135 mmol/L. Statt der ID zeigt die letzte Spalte diesmal den Patienten:

```bash
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|718-7&value-quantity=lt10" \
  | jq -r '.entry[].resource | "\(.effectiveDateTime[0:16])  \(.valueQuantity.value) \(.valueQuantity.unit)  \(.subject.reference[8:20])"' | sort

curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|2951-2&value-quantity=lt135" \
  | jq -r '.entry[].resource | "\(.effectiveDateTime[0:16])  \(.valueQuantity.value) \(.valueQuantity.unit)  \(.subject.reference[8:])"' | sort
```

✅ **Erwartetes Ergebnis:** 6 Hämoglobin- und 7 Natrium-Werte, alle vom Patienten `PID-6f82e92c`:

```text
2018-06-21T15:53  8.8 g/dl  PID-6f82e92c[...]
2019-10-01T15:55  8.3 g/dl  PID-6f82e92c[...]
2023-03-17T14:04  8.8 g/dl  PID-6f82e92c[...]
...
2016-03-18T11:33  132.0 mmol/l  PID-6f82e92c[...]
...
2019-08-27T13:00  130.0 mmol/l  PID-6f82e92c[...]
```

🧩 **Was du gerade gesehen hast:** Auch hier ist es immer derselbe Patient, derjenige mit 1.720 Laborwerten aus 4.1. Das Ergebnis der Abfrage sagt deshalb mehr über die Verteilung der Musterdaten als über Hämoglobin oder Natrium.

___

## 💻 5. Ressourcen verknüpfen

### Abfrage 5.1: Chaining – über eine Referenz hinweg filtern

„Alle R51-Diagnosen bei **Frauen**“ – das Geschlecht steht nicht in der Condition, sondern im verknüpften Patient:

```bash
curl -s "http://localhost:8080/fhir/Condition?code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|R51&subject:Patient.gender=female&_summary=count" | jq '.total'
# → 13
```

13 Diagnosen, aber wie in 3.2 gesehen nur von zwei Patientinnen.

„Wie viele Diagnosen stammen aus **ambulanten** bzw. **stationären** Fällen?“ – die Fallart steht im verknüpften Encounter:

```bash
curl -s "http://localhost:8080/fhir/Condition?encounter:Encounter.class=AMB&_summary=count" | jq '.total'
# → 144
curl -s "http://localhost:8080/fhir/Condition?encounter:Encounter.class=IMP&_summary=count" | jq '.total'
# → 315
```

🧩 **Was du gerade gesehen hast:** Zusammen sind das 459 von 482 Diagnosen. Die übrigen 23 haben gar keinen `encounter`. Eine Chaining-Suche findet nur Ressourcen, bei denen die Referenz auch gesetzt ist.

### Abfrage 5.2: Reverse Chaining (`_has`) – Patienten über ihre Daten finden

„Welche **Patienten** haben eine R51-Diagnose?“ – hier wird umgekehrt gesucht: Patienten, auf die eine passende Condition verweist:

```bash
curl -s "http://localhost:8080/fhir/Patient?_has:Condition:subject:code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|R51" \
  | jq -r '.entry[].resource | "\(.id[0:])  \(.gender)  \(.birthDate)"'
```

✅ **Erwartetes Ergebnis:** dieselben 5 Patienten wie in 3.2, diesmal als Patient-Ressourcen (3 männlich, 2 weiblich):

```text
0002690836  male  1955-01-01
PID-4f1c98e0b7ac6ef8  male  2001-01
PID-5c07503c9075b590  male  1980-01
PID-732cc339b6bf755d  female  1980-01
PID-e5d803e49c59d57d  female  1940-01
```

`_has` lässt sich mit anderen Parametern kombinieren – z. B. Patienten mit **Pflegegrad 3** (OPS `9-984.8`):

```bash
curl -s "http://localhost:8080/fhir/Patient?_has:Procedure:subject:code=http://fhir.de/CodeSystem/bfarm/ops|9-984.8&_summary=count" | jq '.total'
# → 2
```

### Abfrage 5.3: `_include` – Befund mit allen Einzelwerten

In 4.3 bist du auf einen Kaliumwert von 8.8 mmol/L gestoßen. Ein Laborbefund (`DiagnosticReport`) verweist über `result` auf seine Einzelwerte. Mit `result=` findest du den Befund, der diesen Wert enthält, und mit `_include` kommen alle seine Einzelwerte in derselben Antwort mit:

```bash
curl -s "http://localhost:8080/fhir/DiagnosticReport?result=Observation/LAB-fa39d35917e47c1e366944975d3ae03005cc30bb9822b4972403b67f&_include=DiagnosticReport:result" \
  | jq -r '.entry[] | "\(.search.mode)\t\(.resource.resourceType)\t\([.resource.code.coding[] | select(.system == "http://loinc.org") | .code][0])\t\(.resource.valueQuantity.value // "") \(.resource.valueQuantity.unit // "")\t\(.resource.interpretation[0].coding[0].code // "")"'
```

✅ **Erwartetes Ergebnis** (die Reihenfolge der `include`-Zeilen kann abweichen):

```text
match    DiagnosticReport  11502-2
include  Observation       11557-6  28.0 mmHg     L
include  Observation       32693-4  13.0 mmol/l   H
include  Observation       2947-0   177.0 mmol/l  H
include  Observation       11556-8  153.0 mmHg    H
include  Observation       6298-4   8.8 mmol/l    H
```

🧩 **Was du gerade gesehen hast:**

- `match` ist der gesuchte Befund, `include` sind die mitgelieferten Einzelwerte. Es sind Werte, wie sie bei einer Blutgasanalyse bestimmt werden: pCO₂ (`11557-6`), pO₂ (`11556-8`), Natrium (`2947-0`), Laktat (`32693-4`) und Kalium.
- Nicht nur Kalium ist hoch, in derselben Probe sind auch Natrium und Laktat auffällig. Rufst du wie in 4.3 den Verlauf für den 4. Februar ab, liegt der nächste Kaliumwert zwei Minuten später bei 4.1.
- Einen auffälligen Wert ordnest du also im Kontext ein: im **Verlauf** (Suche nach Patient und Code, 4.3) und im **Befund** (`_include`). Beides holst du dir mit wenigen Suchanfragen, ohne jede Ressource einzeln abzurufen.

### Abfrage 5.4: `_revinclude` – die Patientenakte

Mit `_revinclude` holst du alle Ressourcen, die **auf** einen Patienten verweisen – eine kleine Patientenakte in einer Abfrage. Nimm dafür einen der Patienten mit R51-Diagnose aus [Abfrage 5.2](#abfrage-52-reverse-chaining-_has--patienten-über-ihre-daten-finden). Die Beispielausgaben unten gehören zur Patientin `PID-e5d803e4…` aus 3.2, mit einer anderen ID siehst du andere Zahlen:

```bash
curl -s "http://localhost:8080/fhir/Patient?_has:Condition:subject:code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|R51" \
  | jq -r '.entry[].resource.id'

# Eine der ausgegebenen IDs einsetzen, z. B.:
PATIENT_ID=PID-e5d803e49c59d57d9d3df687dd7993c14438d633d6a7369054a7ff7f

curl -s "http://localhost:8080/fhir/Patient?_id=$PATIENT_ID&_revinclude=Encounter:subject&_revinclude=Condition:subject&_revinclude=Procedure:subject&_revinclude=Observation:subject" \
  | jq -r '.entry[].resource.resourceType' | sort | uniq -c
```

✅ **Erwartetes Ergebnis** (für `PID-e5d803e4…`):

```text
     52 Condition
      5 Encounter
     10 Observation
      1 Patient
      8 Procedure
```

Zuerst der Überblick, dann die Einzelheiten. Welche Diagnosen stecken hinter den 52 Conditions, und wann war die Patientin im Krankenhaus?

```bash
curl -s "http://localhost:8080/fhir/Condition?subject=Patient/$PATIENT_ID&_count=200" \
  | jq -r '.entry[].resource.code.coding[0].code' | sort | uniq -c | sort -rn | head -5

curl -s "http://localhost:8080/fhir/Encounter?subject=Patient/$PATIENT_ID" \
  | jq -r '.entry[].resource | "\(.class.code)  \(.period.start[0:10])  \(.period.end[0:10])"' | sort -k2
```

✅ **Erwartetes Ergebnis** (für `PID-e5d803e4…`):

```text
      7 R51
      7 D64.9
      6 Z11
      5 I10.90
      3 U99.0

IMP  2022-02-14  2024-01-16
IMP  2024-01-01  2024-02-12
IMP  2024-01-17  2024-01-17
IMP  2024-02-12  2024-02-12
IMP  2024-02-23  2024-02-23
```

🧩 **Was du gerade gesehen hast:**

- Die 52 Diagnosen verteilen sich auf 19 verschiedene Codes. Viele davon sind mehrfach dokumentiert, wie R51 in 3.2.
- Die Patientin hatte fünf stationäre Fälle (`IMP`). Der erste dauert laut `period` fast zwei Jahre und überschneidet sich mit dem zweiten. Auch das ist eine Stelle, die man mit dem Standort klären könnte, bevor man Liegezeiten auswertet.
- So arbeitest du dich durch eine Patientenakte: erst zählen, was es gibt, dann gezielt einzelne Ressourcentypen ansehen.

___

## 🔍 6. Auffälligkeiten in den Daten

Echte Routinedaten sind selten fehlerfrei. Mit FHIR-Search lassen sich Widersprüche aufspüren – und manchmal stellt sich heraus, dass es keine sind.

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

- `Patient.deceased[x]` beschreibt den **aktuellen** Stand, als `deceasedDateTime` samt Todeszeitpunkt, als `deceasedBoolean` nur mit ja/nein.
- Die Vitalstatus-Observation ist eine **Momentaufnahme**: „Zum Zeitpunkt `effective[x]` war der Patient lebend (bzw. tot).“

Ein Patient, der 2023 bei einem Aufenthalt mit „L“ dokumentiert wurde und 2025 verstorben ist, hat beide Angaben zu Recht. Ein **echter** Widerspruch läge erst vor, wenn eine „L“-Observation **nach** dem Tod datiert ist. Dafür brauchst du ein Todesdatum. Wie ist `deceased` in den Daten angegeben? Der Überblick zeigt je Patient die gekürzte ID (also einen Hinweis auf den Standort, siehe 2.1) und den Wert:

```bash
curl -s "http://localhost:8080/fhir/Patient?_count=300" \
  | jq -r '.entry[].resource | "\(.id[0:3])  deceasedBoolean=\(.deceasedBoolean)  deceasedDateTime=\(.deceasedDateTime)"' \
  | sort | uniq -c
```

✅ **Erwartetes Ergebnis** (dazu Zeilen für deine Testpatienten aus Übung 2, z. B. `DIK` und `exa`):

```text
      3 000  deceasedBoolean=false  deceasedDateTime=null
      1 Pat  deceasedBoolean=null  deceasedDateTime=null
     12 PID  deceasedBoolean=null  deceasedDateTime=null
    259 PID  deceasedBoolean=true  deceasedDateTime=null
```

Ein Todesdatum gibt es bei keinem Patienten. Bleibt die eine „T“-Observation: Zu wem gehört sie, und was ist für diesen Patienten sonst dokumentiert?

```bash
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|67162-8&value-concept=https://www.medizininformatik-initiative.de/fhir/core/modul-person/CodeSystem/Vitalstatus|T" \
  | jq -r '.entry[].resource.subject.reference'
# → Patient/PID-9ecfd17f3070a0ca1e734fd31fbb123d6cdbda94431103c55910053a

curl -s -G "http://localhost:8080/fhir/Observation" \
  --data-urlencode "code=http://loinc.org|67162-8" \
  --data-urlencode "subject=Patient/PID-9ecfd17f3070a0ca1e734fd31fbb123d6cdbda94431103c55910053a" \
  | jq -r '.entry[].resource | "\(.effectiveDateTime[0:16])  \(.valueCodeableConcept.coding[0].code)"' | sort
```

✅ **Erwartetes Ergebnis:**

```text
2022-07-20T10:44  L
2022-07-20T21:02  T
```

🧩 **Was du gerade gesehen hast:**

- Für den einzigen Patienten mit „T“ passt alles zusammen: morgens lebend, abends verstorben, und `deceasedBoolean` ist `true`.
- Alle UKSH-Patienten mit Angabe sind als verstorben markiert, die UKHD-Patienten als lebend. Weil nirgends ein Todesdatum steht, lässt sich für die übrigen 258 „verstorbenen“ Patienten nicht prüfen, ob eine „L“-Observation zu spät kommt. Diese Prüfung ist mit den Musterdaten nicht möglich.
- Jede Angabe im KDS hat einen Zeitbezug. Zwei Angaben, die nicht zusammenpassen, sind erst dann ein Widerspruch, wenn sich dieselbe Aussage zum selben Zeitpunkt unterscheidet. Ob du das prüfen kannst, hängt davon ab, welche Elemente überhaupt befüllt sind.

___

## 💻 7. Skriptbasierter Ausblick (Python/R)

Für wiederkehrende Abfragen und statistische Auswertungen lohnt sich ein Skript. Bibliotheken übernehmen dabei das Blättern durch die Seiten und wandeln die Ressourcen in Tabellen um. Beide Beispiele holen alle Hämoglobin-Werte.

### 7.1 Python: fhir-pyrate

```bash
pip install fhir-pyrate
```

> 💡 Neuere Ubuntu-/Debian-Versionen (auch unter WSL2) verweigern `pip install` außerhalb einer virtuellen Umgebung mit dem Fehler `externally-managed-environment`. Lege dann vorher eine virtuelle Umgebung an:
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

- Die Standorte setzen Pseudonymisierung unterschiedlich um. Im vorliegenden Datenauszug (Musterdaten) verraten die ID-Muster, woher eine Ressource stammt.
- Diagnosen und Laborwerte tragen oft nur Codes ohne Klartext. Dieselbe Diagnose steht teils mehrfach im selben Fall.
- Laborwerte gibt es in diesem Datensatz nur für wenige Patienten. Rund 40 % der Laborwerte haben statt eines LOINC-Codes nur einen Platzhalter.
- Die Daten enthalten ungültige Codes. Nicht jede Auffälligkeit ist ein Widerspruch, und manche Prüfung ist mangels befüllter Elemente gar nicht möglich.

___

### Ausblick

- **Übung 5:** Terminologien prüfen mit FHIR-Operationen – Codes nachschlagen und prüfen  
- **Übung 6:** Terminologieserver einrichten und mit dem FHIR Validator Ressourcen gegen Profile prüfen  
- **Übung 7:** Validierungsberichte interpretieren  

___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • **4 · Daten abfragen** • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___
