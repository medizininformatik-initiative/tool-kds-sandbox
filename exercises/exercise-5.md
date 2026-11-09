___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • **5 · Codes prüfen** • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___

# 🔴 Gegen Terminologien prüfen mit FHIR-Operationen

**Nächste Schritte:**

- Finde heraus, welche Codesysteme in den Musterdaten in Blaze stecken
- Schlage Codes nach (`$lookup`), prüfe sie (`$validate-code`) und suche Codes (`$expand`) – am öffentlichen Terminologieserver **tx.fhir.org**
- Prüfe die Codes aus Blaze automatisch und erkenne, wo ein internationaler Terminologieserver an seine Grenzen stößt

In den vorherigen Übungen hast du FHIR-Ressourcen in Blaze geladen und abgefragt. Dabei ging es um die **Struktur** der Daten. Ob ein Code wie `718-7` in einem Laborwert aber tatsächlich existiert, in welcher Version er gilt und wie er heißt, weiß Blaze nicht. Dafür gibt es **Terminologieserver**: Sie kennen Codesysteme (z. B. LOINC) und ValueSets (Auswahllisten von Codes) und beantworten Fragen dazu über standardisierte FHIR-Operationen.

In dieser Übung nutzt du den öffentlichen Terminologieserver von HL7, [tx.fhir.org](https://tx.fhir.org). Du musst nichts installieren und kannst die Operationen sofort ausprobieren. Dabei wirst du sehen, dass tx.fhir.org die deutschen Klassifikationen nicht kennt. Wie du einen Terminologieserver mit ICD-10-GM und OPS einrichtest, lernst du in [Übung 6 · Ressourcen validieren](exercise-6.md).

> ⚠️ **Datenschutz:** tx.fhir.org ist ein öffentlicher Dienst. Bei den Operationen dieser Übung verlassen nur Codes deinen Rechner, keine Ressourcen. Die Musterdatenspende ist ohnehin öffentlich. Echte Patientendaten gehören trotzdem **nie** an einen öffentlichen Server.

___

📋 **Übersicht:**

- [Hintergrund: Terminologien und Terminologieserver](#hintergrund)
- [Schritt 1: Welche Codesysteme stecken in den Daten?](#schritt-1)
- [Schritt 2: Code nachschlagen mit `$lookup`](#schritt-2)
- [Schritt 3: Code prüfen mit `$validate-code`](#schritt-3)
- [Schritt 4: Codes suchen mit `$expand`](#schritt-4)
- [Schritt 5: Codes aus Blaze automatisch prüfen](#schritt-5)
- [Was tx.fhir.org nicht kann](#grenzen)
- [Zusammenfassung und Ausblick](#zusammenfassung)

___

## <a id="hintergrund"></a>📖 Hintergrund: Terminologien und Terminologieserver
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

### Codesysteme im DIZ
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

| Codesystem | Herausgeber | Typische Verwendung im KDS | Beschaffung | Download / Bezug |
| --- | --- | --- | --- | --- |
| **ICD-10-GM** | BfArM | Diagnosen (`Condition.code`) | Kostenfrei (Downloadbedingungen des BfArM) | [BfArM-Downloads](https://www.bfarm.de/DE/Kodiersysteme/Services/Downloads/_node.html) · [Infoseite](https://www.bfarm.de/DE/Kodiersysteme/Klassifikationen/ICD/ICD-10-GM/_node.html) |
| **OPS** | BfArM | Prozeduren (`Procedure.code`) | Kostenfrei (Downloadbedingungen des BfArM) | [BfArM-Downloads](https://www.bfarm.de/DE/Kodiersysteme/Services/Downloads/_node.html) · [Infoseite](https://www.bfarm.de/DE/Kodiersysteme/Klassifikationen/OPS-ICHI/OPS/_node.html) |
| **Alpha-ID-SE** | BfArM | Seltene Erkrankungen (`Condition.code`) | Kostenfrei (Downloadbedingungen des BfArM) | [BfArM-Downloads](https://www.bfarm.de/DE/Kodiersysteme/Services/Downloads/_node.html) · [Infoseite](https://www.bfarm.de/DE/Kodiersysteme/Terminologien/Alpha-ID-SE/_node.html) |
| **ATC** | BfArM / WHO | Wirkstoffe (`Medication.code`) | Kostenfrei (Downloadbedingungen des BfArM) | [BfArM-Downloads](https://www.bfarm.de/DE/Kodiersysteme/Klassifikationen/ATC/Downloads/_node.html) · [Infoseite](https://www.bfarm.de/DE/Kodiersysteme/Klassifikationen/ATC/_node.html) |
| **LOINC** | Regenstrief Institute | Laborwerte (`Observation.code`) | Kostenfrei, eigene LOINC-Lizenz, Registrierung nötig | [LOINC-Downloads](https://loinc.org/downloads/) · [Infoseite](https://loinc.org/) |
| **SNOMED CT** | SNOMED International | Klinische Begriffe (viele Elemente) | Lizenzpflichtig; in Deutschland national lizenziert, kostenfreie Affiliate-Lizenz über das BfArM | [BfArM-Lizenz](https://www.bfarm.de/DE/Kodiersysteme/Terminologien/SNOMED-CT/Lizenz/_node.html) (Download nach Lizenzierung) · [Infoseite](https://www.bfarm.de/DE/Kodiersysteme/Terminologien/SNOMED-CT/_node.html) |
| **UCUM** | Regenstrief Institute | Maßeinheiten (`valueQuantity.code`) | Kostenfrei ([Nutzungsbedingungen](https://ucum.org/license)) | [UCUM-Repository](https://github.com/ucum-org/ucum) · [Infoseite](https://ucum.org/ucum) |

> 💡 **Klassifikation vs. FHIR-Paket:** Das BfArM stellt die Klassifikationen als Text-, XML- oder CSV-Dateien bereit. Ein FHIR-Terminologieserver braucht sie aber als FHIR-Ressource (`CodeSystem`). Die MII stellt ICD-10-GM, OPS und Alpha-ID-SE deshalb zusätzlich als fertige FHIR-Pakete bereit ([gitlab.com/mii-termserv](https://gitlab.com/mii-termserv)). Diese Pakete lädst du in [Übung 6 · Ressourcen validieren](exercise-6.md#schritt-1a) in deinen eigenen Terminologieserver. Eine Ausnahme ist **UCUM**: Einheiten wie `mmol/L` werden nach Regeln aus Bausteinen zusammengesetzt, eine vollständige Liste als `CodeSystem` gibt es deshalb nicht. Terminologieserver haben UCUM fest eingebaut und lesen dazu die Definitionsdatei `ucum-essence.xml` aus dem UCUM-Repository.

> ⚠️ **Versionen:** Codesysteme ändern sich regelmäßig, die ICD-10-GM z. B. jährlich, LOINC zweimal im Jahr. Ein Code, der 2023 gültig war, kann 2026 fehlen oder anders heißen. Ein Terminologieserver kann mehrere Versionen parallel vorhalten.

### Was kann ein Terminologieserver?
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

Alle FHIR-Terminologieserver bieten dieselben Standard-Operationen an:

| Operation | Frage | Beispiel |
| --- | --- | --- |
| `$lookup` | Was bedeutet dieser Code? | LOINC `718-7` → „Hemoglobin [Mass/volume] in Blood“ |
| `$validate-code` | Gibt es diesen Code (in diesem ValueSet)? Passt der Anzeigetext? | Ist `718-8` ein gültiger LOINC-Code? |
| `$expand` | Welche Codes enthält ein ValueSet? | Alle LOINC-Codes, die „hemoglobin“ enthalten |
| `$translate` | Wie lautet der Code in einem anderen System? | Mapping über eine ConceptMap |

### Terminologieserver im Überblick
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

| | tx.fhir.org | MII Ontoserver | Eigener FHIRsmith |
| --- | --- | --- | --- |
| **Adresse** | [`https://tx.fhir.org/r4`](https://tx.fhir.org/r4) | [`https://ontoserver.mii-termserv.de/fhir`](https://ontoserver.mii-termserv.de/fhir) | z. B. `http://localhost:8081/fhir` |
| **Betreiber** | HL7 (öffentlich) | MII Service Unit Terminologie (SU-TermServ) | Du selbst |
| **Software** | FHIRsmith | Ontoserver (CSIRO) | FHIRsmith |
| **Zugang** | Öffentlich, ohne Login | Client-Zertifikat, nur für Personen und Einrichtungen in Deutschland | Lokal, ohne Login |
| **Inhalt** | Internationale Terminologien (u. a. LOINC, SNOMED CT International, UCUM, HL7-Codesysteme) | MII-/KDS-Terminologien inkl. deutscher Klassifikationen | Was du lädst |
| **Einsatz** | Standard für IG Publisher und HL7-Validator | Entwicklung, keine Personendaten | Lernen, offline, eigene Tests |
| **In dieser Schulung** | Übung 5 | Übung 6 (optional) | Übung 6 |

___

## <a id="schritt-1"></a>💻 Schritt 1: Welche Codesysteme stecken in den Daten?
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

> ⚠️ **Voraussetzung:** Blaze läuft auf `http://localhost:8080` und enthält die Musterdaten aus [Übung 3 · Musterdaten laden](exercise-3.md).

Jeder Code in FHIR steht zusammen mit seinem Codesystem in einem `Coding`: `{"system": "http://loinc.org", "code": "718-7"}`. Der folgende Befehl holt alle Ressourcen eines Typs aus Blaze und gibt von jedem `Coding` das System als eine Zeile aus. `..` durchsucht dabei die ganze Ressource, `select(has("system") and has("code"))` behält nur Objekte, die wie ein `Coding` aussehen. Gezählt wird wie in [Übung 4 · Daten abfragen](exercise-4.md) mit `sort | uniq -c`:

```bash
for type in Condition Procedure Observation Encounter; do
  echo "== $type"
  curl -s "http://localhost:8080/fhir/$type?_count=4000" \
    | jq -r '.entry[].resource | .. | objects | select(has("system") and has("code")) | .system' \
    | sort | uniq -c | sort -rn
done
```

✅ **Erwartetes Ergebnis** (gekürzt; kleine Abweichungen durch deine Testressourcen aus Übung 2 sind normal):

```text
== Condition
    482 http://fhir.de/CodeSystem/bfarm/icd-10-gm
...
== Procedure
    203 http://snomed.info/sct
    203 http://fhir.de/CodeSystem/bfarm/ops
      4 https://fhir.kbv.de/CodeSystem/KBV_CS_SFHIR_ICD_SEITENLOKALISATION
      3 https://fhir.kbv.de/ValueSet/KBV_VS_SFHIR_ICD_SEITENLOKALISATION
...
== Observation
   4951 http://unitsofmeasure.org
   4867 http://loinc.org
   3638 http://terminology.hl7.org/CodeSystem/observation-category
...
   1888 http://medic.uksh.de/fhir/CodeSystem/Laborparameter
...
   1583 https://www.medizininformatik-initiative.de/fhir/core/modul-person/CodeSystem/Vitalstatus
...
== Encounter
   1329 http://terminology.hl7.org/CodeSystem/v3-ActCode
   1329 http://fhir.de/CodeSystem/Kontaktebene
...
     36 http://hl7.org/fhir/ValueSet/diagnosis-role
...
```

🧩 **Was du gerade gesehen hast:** Du findest drei Arten von Codesystemen:

- **International:** LOINC, SNOMED CT, UCUM und die Codesysteme von HL7 (`terminology.hl7.org`)
- **Deutsch:** ICD-10-GM und OPS des BfArM, Codesysteme der deutschen Basisprofile (`fhir.de`) und der MII (`medizininformatik-initiative.de`)
- **Lokal:** Hauscodes des UKSH (`medic.uksh.de`), die nur der Standort selbst kennt

Einzelne Zeilen sehen nicht wie ein Codesystem aus: `…/ValueSet/KBV_VS_SFHIR_ICD_SEITENLOKALISATION` bei Procedure und `…/ValueSet/diagnosis-role` bei Encounter enthalten `ValueSet` in der URL. Auf `diagnosis-role` kommst du am Ende von [Schritt 5](#schritt-5) zurück.

___

## <a id="schritt-2"></a>💻 Schritt 2: Code nachschlagen mit `$lookup`
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

Lege die Adresse des Terminologieservers in einer Variablen ab. So kannst du später mit denselben Befehlen einen anderen Server ansprechen:

```bash
TX=https://tx.fhir.org/r4
curl -s "$TX/metadata" | jq '{software: .software.name, version: .software.version, fhirVersion}'
```

> ⚠️ Eine Shell-Variable gilt nur im aktuellen Terminalfenster. Öffnest du ein neues Fenster, setze `TX` dort erneut.

Die URLs von Terminologie-Operationen enthalten oft Sonderzeichen. Mit `curl -G` und `--data-urlencode` übernimmt `curl` das korrekte Kodieren der Parameter. Vor dem Namen der Operation steht ein `\`, damit die Shell `$lookup` nicht als Variable liest, `$TX` aber schon.

Was bedeutet der LOINC-Code `718-7`, der in den Musterdaten bei Hämoglobin steht?

```bash
curl -s -G "$TX/CodeSystem/\$lookup" \
  --data-urlencode "system=http://loinc.org" \
  --data-urlencode "code=718-7" \
  | jq -r '.parameter[] | select(.name=="name" or .name=="version" or .name=="display") | "\(.name): \(.valueString)"'
```

✅ **Erwartetes Ergebnis:**

```text
name: Logical Observation Identifier Names and Codes (LOINC)
version: 2.83
display: Hemoglobin [Mass/volume] in Blood
```

Probiere dasselbe für einen SNOMED-CT-Code aus den Laborbefunden:

```bash
curl -s -G "$TX/CodeSystem/\$lookup" \
  --data-urlencode "system=http://snomed.info/sct" \
  --data-urlencode "code=260385009" \
  | jq -r '.parameter[] | select(.name=="version" or .name=="display") | "\(.name): \(.valueString)"'
```

✅ **Erwartetes Ergebnis:** `display: Negative`. Die Version zeigt, dass tx.fhir.org die **internationale** Edition von SNOMED CT nutzt (`…/900000000000207008/version/…`). Deutsche Bezeichnungen enthält sie nicht.

___

## <a id="schritt-3"></a>💻 Schritt 3: Code prüfen mit `$validate-code`
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

Ein gültiger Code:

```bash
curl -s -G "$TX/CodeSystem/\$validate-code" \
  --data-urlencode "url=http://loinc.org" \
  --data-urlencode "code=718-7" \
  | jq -r '.parameter[] | select(.name=="result" or .name=="message" or .name=="display") | "\(.name): \(if has("valueBoolean") then .valueBoolean else .valueString end)"'
```

✅ `result: true` und `display: Hemoglobin [Mass/volume] in Blood`

Ein Code, den es nicht gibt (eine Ziffer geändert):

```bash
curl -s -G "$TX/CodeSystem/\$validate-code" \
  --data-urlencode "url=http://loinc.org" \
  --data-urlencode "code=718-8" \
  | jq -r '.parameter[] | select(.name=="result" or .name=="message" or .name=="display") | "\(.name): \(if has("valueBoolean") then .valueBoolean else .valueString end)"'
```

✅ `result: false` und `message: Unknown code '718-8' in the CodeSystem 'http://loinc.org' version '2.83'`

> 💡 Die letzte Ziffer eines LOINC-Codes ist eine Prüfziffer. Tippfehler fallen deshalb fast immer auf.

Eine Diagnose aus den Musterdaten, ICD-10-GM `R51` (Kopfschmerz):

```bash
curl -s -G "$TX/CodeSystem/\$validate-code" \
  --data-urlencode "url=http://fhir.de/CodeSystem/bfarm/icd-10-gm" \
  --data-urlencode "code=R51" \
  | jq -r '.parameter[] | select(.name=="result" or .name=="message" or .name=="display") | "\(.name): \(if has("valueBoolean") then .valueBoolean else .valueString end)"'
```

✅ `result: false` und `message: A definition for CodeSystem 'http://fhir.de/CodeSystem/bfarm/icd-10-gm' could not be found, so the code cannot be validated`

🧩 **Was du gerade gesehen hast:** Vergleiche die beiden `false`-Antworten. Bei `718-8` sagt der Server „diesen Code gibt es nicht“. Bei `R51` sagt er „dieses Codesystem kenne ich nicht“ – über den Code selbst weiß er nichts. Das ist ein wichtiger Unterschied: Ein `false` heißt nicht automatisch, dass die Daten falsch sind.

___

## <a id="schritt-4"></a>💻 Schritt 4: Codes suchen mit `$expand`
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

`$expand` listet die Codes eines ValueSets auf. Ein ValueSet aus der FHIR-Spezifikation, das du aus `Patient.gender` kennst:

```bash
curl -s -G "$TX/ValueSet/\$expand" \
  --data-urlencode "url=http://hl7.org/fhir/ValueSet/administrative-gender" \
  | jq -r '.expansion.contains[] | "\(.code)\t\(.display)"'
```

✅ **Erwartetes Ergebnis:** die vier Codes `male`, `female`, `other` und `unknown`.

Jedes Codesystem hat außerdem ein ValueSet mit allen seinen Codes. Bei LOINC lautet seine URL `http://loinc.org/vs`. Mit `filter` durchsuchst du die Anzeigetexte:

```bash
curl -s -G "$TX/ValueSet/\$expand" \
  --data-urlencode "url=http://loinc.org/vs" \
  --data-urlencode "filter=hemoglobin" \
  --data-urlencode "count=10" \
  | jq -r '.expansion.contains[] | "\(.code)\t\(.display)"'
```

> 💡 **Ausprobieren:** Ändere den Filter (z. B. `potassium` oder `sodium`). Die Treffer enthalten neben Codes für Laborwerte (z. B. `718-7`) auch LOINC-„Parts“ (Codes, die mit `LP` beginnen) – Bausteine, aus denen LOINC seine Codes zusammensetzt.

___

## <a id="schritt-5"></a>🛠️ Schritt 5: Codes aus Blaze automatisch prüfen
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

Jetzt verbindest du beide Server: Du nimmst aus Blaze **je Codesystem einen Code** und prüfst ihn an tx.fhir.org.

Zuerst sammelst du die Codes in einer Datei `codes.txt`:

```bash
for type in Condition Procedure Observation Encounter; do
  curl -s "http://localhost:8080/fhir/$type?_count=4000" \
    | jq -r '[.entry[].resource | .. | objects | select(has("system") and has("code"))]
             | group_by(.system) | .[] | "\(.[0].system) \(.[0].code)"'
done | sort -u > codes.txt

cat codes.txt
```

Dann prüfst du jede Zeile am Terminologieserver:

```bash
while read -r system code; do
  result=$(curl -s -G "$TX/CodeSystem/\$validate-code" \
    --data-urlencode "url=$system" \
    --data-urlencode "code=$code" \
    | jq -r '.parameter[] | select(.name=="result") | .valueBoolean')
  echo -e "$result\t$system"
done < codes.txt
```

> 💡 **Als Skript:** Beide Befehle zusammen liegen auch im Repository. Ohne Angabe prüft das Skript an tx.fhir.org:
>
> ```bash
> bash ~/tool-kds-sandbox/solution-exercise-5/check_codesystems.sh
> ```
>
> Du brauchst es in [Übung 6 · Ressourcen validieren](exercise-6.md) wieder, um deinen eigenen Terminologieserver mit tx.fhir.org zu vergleichen.

✅ **Erwartetes Ergebnis** (Auszug):

```text
false	http://fhir.de/CodeSystem/bfarm/icd-10-gm
false	http://fhir.de/CodeSystem/bfarm/ops
false	http://fhir.de/CodeSystem/dgkev/Aufnahmeanlass
...
false	http://fhir.de/CodeSystem/Kontaktebene
false	http://hl7.org/fhir/ValueSet/diagnosis-role
true	http://loinc.org
false	http://medic.uksh.de/Codeystem/unknown
false	http://medic.uksh.de/fhir/CodeSystem/Laborparameter
...
true	http://snomed.info/sct
...
true	http://terminology.hl7.org/CodeSystem/diagnosis-role
...
false	http://the-standard.org/
true	http://unitsofmeasure.org
true	urn:iso:std:iso:11073:10101
```

Bei `false` sagt dir erst die `message`, ob der Code falsch ist oder der Server das Codesystem nicht kennt. Prüfe dazu eine Zeile einzeln mit dem Befehl aus [Schritt 3](#schritt-3), z. B. die Kontaktebene, die in jedem Encounter steht:

```bash
curl -s -G "$TX/CodeSystem/\$validate-code" \
  --data-urlencode "url=http://fhir.de/CodeSystem/Kontaktebene" \
  --data-urlencode "code=einrichtungskontakt" \
  | jq -r '.parameter[] | select(.name=="result" or .name=="message") | "\(.name): \(if has("valueBoolean") then .valueBoolean else .valueString end)"'
```

✅ **Erwartetes Ergebnis:** `result: false` und `message: A definition for CodeSystem 'http://fhir.de/CodeSystem/Kontaktebene' could not be found, so the code cannot be validated`

🧩 **Was du gerade gesehen hast:** Bei den `false`-Zeilen gehören die Codes zu Systemen, die tx.fhir.org nicht als Codesystem kennt. Über die Codes selbst sagt das Ergebnis deshalb nichts. Sortiert nach Herkunft:

| Codesystem | tx.fhir.org | Warum? |
| --- | --- | --- |
| `http://loinc.org`, `http://snomed.info/sct`, `http://unitsofmeasure.org` | ✅ `true` | Internationale Terminologien |
| `http://terminology.hl7.org/CodeSystem/...` | ✅ `true` | Codesysteme von HL7 |
| `urn:iso:std:iso:11073:10101` | ✅ `true` | Internationale Nomenklatur für Medizingeräte (z. B. Herzfrequenz vom Monitor) |
| `http://fhir.de/CodeSystem/bfarm/icd-10-gm`, `.../ops` | ❌ unbekannt | Deutsche Klassifikationen, auf tx.fhir.org nicht geladen |
| `http://fhir.de/CodeSystem/...` (z. B. `Kontaktebene`, `dgkev/Aufnahmeanlass`) | ❌ unbekannt | Codesysteme der deutschen Basisprofile |
| `https://fhir.kbv.de/CodeSystem/...` (z. B. `KBV_CS_SFHIR_ICD_SEITENLOKALISATION`) | ❌ unbekannt | Codesysteme der KBV |
| `https://www.medizininformatik-initiative.de/...` (z. B. `Vitalstatus`) | ❌ unbekannt | Codesysteme der MII |
| `http://medic.uksh.de/...` | ❌ unbekannt | Lokale Hauscodes – kennt kein externer Terminologieserver |
| `http://hl7.org/fhir/ValueSet/diagnosis-role`, `https://fhir.kbv.de/ValueSet/...` | ❌ unbekannt | Keine Codesystem-, sondern ValueSet-URLs (ein Fehler in den Daten, siehe unten) |
| `http://the-standard.org/` | ❌ unbekannt | Keine Codesystem-URL, die tx.fhir.org kennt |

Für die Validierung deutscher KDS-Daten reicht tx.fhir.org allein also nicht aus. Wie du einen Terminologieserver mit diesen Inhalten bekommst, siehst du in [Übung 6 · Ressourcen validieren](exercise-6.md).

### 🔍 Ein Fehler in den Daten
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

In Schritt 1 ist dir bei Encounter das „Codesystem“ `http://hl7.org/fhir/ValueSet/diagnosis-role` aufgefallen. Es steht in `Encounter.diagnosis.use`, der Rolle einer Diagnose im Fall. Sieh dir zuerst an, welche Systeme und Codes dort vorkommen:

```bash
curl -s "http://localhost:8080/fhir/Encounter?_count=4000" \
  | jq -r '.entry[].resource.diagnosis[]?.use.coding[]? | "\(.system)  \(.code)"' | sort | uniq -c
```

✅ **Erwartetes Ergebnis:**

```text
      2 http://hl7.org/fhir/ValueSet/diagnosis-role  AD
      2 http://hl7.org/fhir/ValueSet/diagnosis-role  CC
     23 http://hl7.org/fhir/ValueSet/diagnosis-role  CM
      9 http://hl7.org/fhir/ValueSet/diagnosis-role  DD
      7 http://terminology.hl7.org/CodeSystem/diagnosis-role  AD
      8 http://terminology.hl7.org/CodeSystem/diagnosis-role  CC
```

Dieselben Codes stehen also unter zwei verschiedenen URLs. Welche Encounter nutzen welche Variante? Wie in [Übung 3](exercise-3.md) gibt `jq -c` jede Ressource als eine Zeile aus, `grep` sucht darin:

```bash
curl -s "http://localhost:8080/fhir/Encounter?_count=4000" | jq -c '.entry[].resource' \
  | grep 'ValueSet/diagnosis-role' | jq -r '.id'

curl -s "http://localhost:8080/fhir/Encounter?_count=4000" | jq -c '.entry[].resource' \
  | grep 'CodeSystem/diagnosis-role' | jq -r '.id'
```

✅ **Erwartetes Ergebnis:** 8 IDs wie `Encounter-8163579` für die erste Variante, 7 IDs wie `0061845260-e` für die zweite.

Sieh dir die Stelle in einem der Encounter an:

```bash
curl -s "http://localhost:8080/fhir/Encounter/Encounter-8163579" | jq '.diagnosis[0]'
```

✅ **Erwartetes Ergebnis** (ein Ausschnitt):

```json
{
  "condition": { "reference": "Condition/Diagnosis-002" },
  "use": {
    "coding": [
      { "system": "http://hl7.org/fhir/ValueSet/diagnosis-role", "code": "DD" },
      { "system": "http://hl7.org/fhir/ValueSet/diagnosis-role", "code": "CM" }
    ]
  }
}
```

🧩 **Was du gerade gesehen hast:** An den ID-Mustern aus [Übung 4, Abfrage 2.1](exercise-4.md) erkennst du die Standorte: `Encounter-…` ist das UKW, `…-e` das UKHD. Die UKW-Encounter tragen in `system` die URL eines **ValueSets**, die UKHD-Encounter die eines **CodeSystems**. Welche Variante richtig ist, klärst du jetzt Schritt für Schritt.

### 💻 Welche Variante ist richtig?
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

So findest du heraus, welche der beiden URLs in `system` gehört:

1. **Profil der Daten herausfinden:** Welche Regeln für eine Ressource gelten, steht in ihrem Profil. Welches Profil das ist, gibt die Ressource selbst in `meta.profile` an. Schau dir einen betroffenen Encounter aus der Ausgabe oben an:

```bash
curl -s "http://localhost:8080/fhir/Encounter/Encounter-8163579" | jq '.meta.profile'
```

✅ **Erwartetes Ergebnis:**

```json
[
  "https://www.medizininformatik-initiative.de/fhir/core/modul-fall/StructureDefinition/KontaktGesundheitseinrichtung"
]
```

> 💡 Das ist die **kanonische URL** des Profils. Sie identifiziert das Profil eindeutig, ist aber nicht unbedingt eine Webseite. Der UKHD-Encounter `0061845260-e` nennt dasselbe Profil, zusätzlich mit der Version `|2024.0.0`.

2. **Profil nachschlagen:** Kopiere die URL in das Suchfeld von [Simplifier: Resolve Canonical](https://simplifier.net/resolve). Simplifier ist die Plattform, auf der die MII ihre Profile veröffentlicht. Statt direkt auf ein Profil zu springen, zeigt Simplifier eine Trefferliste – dieselbe kanonische URL kommt in mehreren Paketen und Projekten vor. Die Sterne zeigen, wie gut ein Treffer passt; `claimed canonical` heißt, dass das Projekt die URL offiziell für sich beansprucht.
   - Der beste Treffer ist das Paket **`de.medizininformatikinitiative.kerndatensatz.fall@2025.0.1`** – das Kerndatensatz-Modul Fall in der Version, die zeitlich zu den Musterdaten passt.
   - Ab 2026 ist das Modul Fall Teil des Moduls Basis (`de.medizininformatikinitiative.kerndatensatz.base`). Dort findest du das Profil als [MII_PR_Fall_KontaktGesundheitseinrichtung](https://simplifier.net/mii-kerndatensatz-basis/mii_pr_fall_kontaktgesundheitseinrichtung).

   Öffne den besten Treffer und suche das Element `Encounter.diagnosis.use`. Sein Binding verweist auf das **ValueSet** `http://hl7.org/fhir/ValueSet/diagnosis-role`.

> 💡 Das Binding von `Encounter.diagnosis.use` ist in allen Versionen des Profils gleich – von 2024 bis zum heutigen Modul Basis. Für diese Frage ist es also egal, welchen Treffer du öffnest.

3. **Das ValueSet auflösen:** Lass dir die Codes dieses ValueSets mit `$expand` anzeigen. Die zweite Spalte zeigt, aus welchem **Codesystem** sie stammen:

```bash
curl -s -G "$TX/ValueSet/\$expand" \
  --data-urlencode "url=http://hl7.org/fhir/ValueSet/diagnosis-role" \
  | jq -r '.expansion.contains[] | "\(.code)\t\(.system)\t\(.display)"'
```

   ✅ Alle Codes (`AD`, `DD`, `CC`, `CM`, …) stammen aus dem CodeSystem `http://terminology.hl7.org/CodeSystem/diagnosis-role`.

4. **Die falsche Variante prüfen:** So antwortet der Terminologieserver, wenn die ValueSet-URL als Codesystem verwendet wird:

```bash
curl -s -G "$TX/CodeSystem/\$validate-code" \
  --data-urlencode "url=http://hl7.org/fhir/ValueSet/diagnosis-role" \
  --data-urlencode "code=CM" \
  | jq -r '.parameter[] | select(.name=="result" or .name=="message") | "\(.name): \(if has("valueBoolean") then .valueBoolean else .valueString end)"'
```

   ✅ `result: false` und `message: The Coding references a value set, not a code system ('http://hl7.org/fhir/ValueSet/diagnosis-role')`

🧩 **Was du gerade gesehen hast:**

- Die Kette lautet: Ressource → `meta.profile` → Profil → Binding → ValueSet → `$expand` → CodeSystem. Diesen Weg kannst du immer gehen, wenn du wissen willst, welche Codes an einer Stelle erlaubt sind und woher sie kommen.
- In `Coding.system` gehört immer die URL des **CodeSystems**. Das ValueSet legt nur fest, welche Codes erlaubt sind. Bei den UKW-Encountern steht dort die URL des ValueSets. Das ist ein **Fehler in den Ressourcen**.
- Die Musterdatenspende ist ein historischer Datenstand; an den Standorten sind solche Fehler inzwischen in der Regel behoben. Gefunden hast du diesen Fehler nicht durch eine gezielte Suche, sondern weil eine Zeile im Überblick aus Schritt 1 nicht ins Bild passte.

___

## <a id="grenzen"></a>🔍 Was tx.fhir.org nicht kann
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

tx.fhir.org ist für internationale Terminologien gemacht. Für die Kerndatensatz-Daten eines deutschen DIZ fehlt ihm Wesentliches:

- **Deutsche Klassifikationen** wie ICD-10-GM, OPS, Alpha-ID-SE und ATC (BfArM-Version)
- **Codesysteme der deutschen Basisprofile und der MII**, z. B. `Kontaktebene` oder `Vitalstatus`
- **Deutsche Bezeichnungen**, z. B. die deutsche Edition von SNOMED CT

Ein Validator, der KDS-Daten prüfen soll, braucht deshalb einen Terminologieserver mit diesen Inhalten: den **MII Ontoserver** der SU-TermServ oder einen **eigenen Terminologieserver**. Beides schauen wir uns am Anfang von [Übung 6 · Ressourcen validieren](exercise-6.md) an.

___

## <a id="zusammenfassung"></a>🏁 Zusammenfassung und Ausblick
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

| Schritt | Befehl |
| --- | --- |
| Terminologieserver festlegen | `TX=https://tx.fhir.org/r4` |
| Code nachschlagen | `curl -s -G "$TX/CodeSystem/\$lookup" --data-urlencode "system=…" --data-urlencode "code=…"` |
| Code prüfen | `curl -s -G "$TX/CodeSystem/\$validate-code" --data-urlencode "url=…" --data-urlencode "code=…"` |
| Codes eines ValueSets auflisten | `curl -s -G "$TX/ValueSet/\$expand" --data-urlencode "url=…" --data-urlencode "filter=…"` |

**Was du mitnehmen kannst:**

- Jeder Code gehört zu einem Codesystem. Ohne das richtige `system` ist ein Code wertlos. Ohne Angabe der verwendeten `version` ist die Überprüfbarkeit zumindest fragwürdig.
- Ein Terminologieserver kann nur prüfen, was er kennt. „Codesystem unbekannt“ ist etwas anderes als „Code ungültig“.
- Welche Inhalte ein Terminologieserver hat, entscheidet darüber, was man mit ihm prüfen kann.

___

### Ausblick
<!-- TODO Jenne: Aufgabe nochmals prüfen und ggf. überarbeiten -->

- [Übung 6 · Ressourcen validieren](exercise-6.md): Terminologieserver mit zusätzlichen (deutschen) Klassifikationen einrichten und Ressourcen mit dem MII FHIR Validator gegen die KDS-Profile prüfen
- [Übung 7 · Berichte auswerten](exercise-7.md): Meldungen des Terminologieservers in Validierungsberichten verstehen, Versionen von Codesystemen und Profilen einordnen

___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • **5 · Codes prüfen** • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___
