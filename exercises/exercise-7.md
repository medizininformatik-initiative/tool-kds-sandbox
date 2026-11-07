___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • **7 · Berichte auswerten**
___
___

# 🟤 Interpretieren von Ergebnissen

**Nächste Schritte:**

- Verstehe den Aufbau eines Validierungsberichts (`OperationOutcome`)
- Werte deine Berichte aus [Übung 6 · Ressourcen validieren](exercise-6.md) mit `jq` aus: vom Überblick bis zur gemeldeten Stelle in der Ressource
- Ordne Meldungen ein: Datenfehler, Versionsthema oder Grenze des Setups?
- Lerne, was ein Validator **nicht** findet

In [Übung 6 · Ressourcen validieren](exercise-6.md) hast du Ressourcen mit dem MII FHIR Validator geprüft. Die Antwort war jedes Mal ein **`OperationOutcome`**, die „Sprache“, in der FHIR Ergebnisse und Fehler meldet.

In dieser Übung lernst du, diese Berichte zu **lesen** und **einzuordnen**: Was bedeutet ein `error` im Vergleich zu einer `warning`? Welche Meldung zeigt einen echten Fehler in den Daten, welche nur eine Lücke in deinem Setup?

> 💡 **Warum Berichte interpretieren?**
>
> - **Datenqualität:** Kritische Fehler von akzeptablen Warnungen unterscheiden
> - **Fehlersuche:** Ursachen schnell lokalisieren
> - **DIZ-Alltag:** Validierung beim Import neuer Daten oder vor einer Datenausleitung
> - **Nachweis:** Datenqualitätsprobleme und ihre Behebung dokumentieren

___

📋 **Übersicht:**

- [Hintergrund: Aufbau eines OperationOutcome](#hintergrund)
- [Häufige Validator-Meldungen](#meldungen)
- [Schritt 1: Berichte speichern und auswerten](#schritt-1)
- [Schritt 2: Meldungen einordnen](#schritt-2)
- [Was der Validator nicht findet](#nicht-gefunden)
- [Schritt 3: Validierung automatisieren](#schritt-3)
- [Zusammenfassung und Abschluss](#zusammenfassung)

___

## <a id="hintergrund"></a>📖 Hintergrund: Aufbau eines OperationOutcome

Ein Validierungsbericht ist eine Liste von `issue`-Einträgen. Ein einzelner Eintrag sieht vereinfacht so aus:

```json
{
  "resourceType": "OperationOutcome",
  "issue": [
    {
      "severity": "error",
      "code": "code-invalid",
      "details": {
        "text": "Beschreibung der Meldung in Klartext"
      },
      "expression": [
        "Condition.code.coding[0]"
      ]
    }
  ]
}
```

| Feld | Inhalt |
| --- | --- |
| `severity` | Wie schwer wiegt die Meldung? (siehe unten) |
| `code` | Art des Problems als Code aus dem FHIR-ValueSet [IssueType](https://hl7.org/fhir/R4/valueset-issue-type.html) |
| `details.text` | Die eigentliche Meldung in Klartext |
| `expression` | FHIRPath-Ausdruck: **wo** in der Ressource das Problem liegt |
| `location` | Ältere Ortsangabe; der HL7-Validator ergänzt hier oft Zeile und Spalte |

### Severity: Wie schwer wiegt die Meldung?

| Severity | Bedeutung | Handlung |
| --- | --- | --- |
| **fatal** | Prüfung konnte nicht durchgeführt werden | **Sofort beheben** – z. B. kein gültiges JSON |
| **error** | Ressource verletzt Standard oder Profil | **Beheben** – Validierung gilt als fehlgeschlagen |
| **warning** | Auffälligkeit, Ressource ist trotzdem konform | **Prüfen** – ggf. Behebung sinnvoll |
| **information** | Hinweis, z. B. „All OK“ | Optional lesen |

### Code: Welche Art von Problem?

Eine Auswahl der `code`-Werte, die dir beim Validieren häufig begegnen:

| Code | Bedeutung | Beispiel |
| --- | --- | --- |
| `structure` | Aufbau passt nicht zum Standard | Unbekanntes Element, falscher Datentyp |
| `required` | Pflichtelement fehlt | Kardinalität `1..1` im Profil, Element fehlt |
| `value` | Wert ungültig | Datum im falschen Format |
| `invariant` | Regel (FHIRPath-Constraint) verletzt | z. B. `dom-6`, Constraints aus dem Profil |
| `code-invalid` | Code unbekannt oder nicht im ValueSet | Ungültiger ICD-10-GM-Code |
| `not-found` | Etwas Referenziertes wurde nicht gefunden | Profil oder CodeSystem unbekannt |
| `processing` | Problem bei der Verarbeitung | Terminologieserver nicht erreichbar |
| `informational` | Reine Information | „All OK“ |

> 💡 Ein Problem beim **Binding** (Code nicht im ValueSet) hat keinen eigenen Code `binding`. Es erscheint meist als `code-invalid` und wird erst im `details.text` genauer beschrieben.

___

## <a id="meldungen"></a>📋 Häufige Validator-Meldungen

### A) Bekannte Meldungen im MII-PRO-IG (kein Datenfehler)

| Meldung / Code | Bedeutung | Einordnung | Was tun? |
|---|---|---|---|
| `UNABLE_TO_INFER_CODESYSTEM` – *System URI could not be determined for the code 'en' in ValueSet all-languages* | Sprachcode steht als `valueCode` ohne System | Validator-/Terminologieserver-Thema. Binding ist nur *preferred*. | Optional `valueCoding` mit `urn:ietf:bcp:47` verwenden |
| `Terminology_TX_NoValid_16` – *No valid coding for 'en' from all-languages* | Folgefehler zu oben | Wie oben | Wie oben |
| `Wrong Display Name 'Überhaupt nicht' for http://loinc.org#LA6568-5 - should be 'Not at all'` | Deutsches Display statt englischem LOINC-Original | Bewusste Designentscheidung im IG | Englisches Display primär, deutsch per Translation-Extension |
| `MSG_DRAFT` | Ressource hat Status *draft* | Warnung | Im Entwicklungsstand akzeptabel |
| `dom-6` | Ressource ohne Narrative | Warnung | Narrative ergänzen oder unterdrücken |

### B) Typische Meldungen (sinngemäß, Wortlaut kann abweichen)

| Meldung (sinngemäß) | Bedeutung | Typische Ursache | Was tun? |
|---|---|---|---|
| *Profile reference … could not be resolved / has not been checked* | Profil unbekannt | IG-Paket nicht geladen, falsche Version oder falsche `meta.profile` | Paket über `IG_PARAMS` laden, Canonical und Version prüfen |
| *Minimum cardinality … minimum required = 1, but only found 0* | Pflichtelement fehlt | Ressource unvollständig | Element ergänzen |
| *This element does not match any known slice* | Element passt auf keinen Slice | Falscher Discriminator-Wert, z. B. `system` oder `code` | Slice-Definition im Profil prüfen |
| *Unknown code 'X' in the CodeSystem 'Y'* | Code existiert im CodeSystem nicht | Tippfehler, falsche Version, falsches System | Code per `$lookup` oder `$validate-code` prüfen ([Übung 5 · Codes prüfen](exercise-5.md)) |
| *None of the codings provided are in the value set 'X'* | Code liegt nicht im gebundenen ValueSet | Falscher Code oder falsches System | ValueSet per `$expand` ansehen ([Übung 5 · Codes prüfen](exercise-5.md)) |
| *CodeSystem 'X' could not be found, so the code cannot be validated* | Terminologieserver kennt das System nicht | System nicht geladen oder lizenzpflichtig (LOINC, SNOMED CT) | Inhalt laden oder anderen Terminologieserver verwenden |
| *Unable to validate code … terminology service … error / unavailable* | Terminologieserver nicht erreichbar oder Fehler | Netzwerk, Zertifikat, Server gestoppt | `TX_SERVER` und Erreichbarkeit prüfen |
| *Reference … could not be resolved* | Referenzierte Ressource nicht gefunden | Fehlende Ressource im Bundle | Ressource ergänzen oder Referenz anpassen |
| *URL … does not resolve* (bei Beispiel-URLs) | Beispiel-Domain nicht erreichbar | Test-Canonicals wie `http://example.org` | Beim CLI: `-allow-example-urls true` |
| *Unknown element / Unrecognised property* | Element existiert nicht in der Ressource | Tippfehler, falsche FHIR-Version | Schreibweise und Version prüfen |
| *A code should come from this value set …* (Warning) | Extensible Binding verletzt | Code außerhalb des ValueSets | Ggf. akzeptabel, im Profil prüfen |

___

## <a id="schritt-1"></a>💻 Schritt 1: Berichte speichern und auswerten

> ⚠️ **Voraussetzung:** Blaze und der Validator aus [Übung 6 · Ressourcen validieren](exercise-6.md) laufen. In `~/validator` liegen diese Dateien aus Übung 6:
>
> | Datei | Inhalt | Erstellt in |
> | --- | --- | --- |
> | `hba1c.json` | Deine HbA1c-Observation aus Übung 1 | [Übung 6, Schritt 3](exercise-6.md#schritt-3) |
> | `condition-570762.json` | Diagnose mit dem ungültigen Code `570762` | [Übung 6, Schritt 4.1](exercise-6.md#schritt-4) |
> | `condition-r51.json` | Diagnose `R51` mit der Profilversion `Diagnose\|2024.0.0` | [Übung 6, Schritt 4.2](exercise-6.md#schritt-4) |
> | `diagnosen/` | Die 57 Diagnosen mit `Diagnose\|2024.0.0` und ihre Berichte | [Übung 6, Schritt 4.4](exercise-6.md#schritt-4-4) |
>
> Fehlt eine Datei, führe den jeweiligen Schritt aus Übung 6 noch einmal aus.

Neu in dieser Übung holst du dir einen Hämoglobin-Wert des UKSH (`hb.json`). Die Abfrage verlangt beide Codes, den LOINC-Code und den Hauscode des UKSH:

```bash
cd ~/validator
curl -s -G "http://localhost:8080/fhir/Observation" \
  --data-urlencode "code=http://loinc.org|718-7" \
  --data-urlencode "code=http://medic.uksh.de/fhir/CodeSystem/Laborparameter|LAB_hbe" \
  --data-urlencode "_count=1" \
  | jq '.entry[0].resource' > hb.json
```

Speichere dann die Berichte aller vier Ressourcen als Dateien. So musst du nicht bei jeder Auswertung neu validieren:

```bash
for f in hba1c condition-570762 condition-r51 hb; do
  curl -s -X POST http://localhost:8082/validateResource \
    -H "Content-Type: application/fhir+json" \
    --data @$f.json > bericht-$f.json
done
ls bericht-*.json
```

### 1.1 Überblick: Meldungen je Schwere

Fang mit einem Überblick an: Wie viele Meldungen welcher Schwere enthält jeder Bericht?

```bash
for f in bericht-*.json; do
  echo "$f: $(jq -c '[.issue[].severity] | group_by(.) | map({(.[0]): length}) | add' $f)"
done
```

✅ **Erwartetes Ergebnis:**

```text
bericht-condition-570762.json: {"error":2,"warning":2}
bericht-condition-r51.json: {"information":1,"warning":2}
bericht-hba1c.json: {"error":2,"warning":9}
bericht-hb.json: {"information":1,"warning":6}
```

🧩 **Was du gerade gesehen hast:** Eine Zeile pro Bericht reicht, um zu wissen, wo du hinschauen musst. Fehler haben nur `condition-570762` und `hba1c`. Die beiden anderen Berichte sind fehlerfrei. Ob dabei wirklich gegen ein KDS-Profil geprüft wurde, verrät die Zählung allerdings nicht (siehe [Übung 6, Schritt 4.2](exercise-6.md#schritt-4) und Schritt 2 unten). Bei vielen Berichten gehst du genauso vor: erst zählen, dann gezielt lesen.

### 1.2 Die Fehler eines Berichts lesen

```bash
jq -r '.issue[] | select(.severity == "error" or .severity == "fatal") | "\(.severity) – \(.expression[0])\n  \(.details.text)\n"' bericht-condition-570762.json
```

✅ **Erwartetes Ergebnis** (die zweite Meldung ist gekürzt):

```text
error – Condition.code.coding[0].code
  Unknown code '570762' in the CodeSystem 'http://fhir.de/CodeSystem/bfarm/icd-10-gm' version '2025'

error – Condition.code.coding[0]
  The code provided (http://fhir.de/CodeSystem/bfarm/icd-10-gm#570762) was not found in the value set 'MII VS Diagnose ICD-10-GM' (…), and a code from this value set is required: …
```

### 1.3 An der gemeldeten Stelle nachsehen

Jede Meldung sagt dir in `expression`, **wo** in der Ressource das Problem liegt. Der FHIRPath-Ausdruck `Condition.code.coding[0]` entspricht in `jq` dem Pfad `.code.coding[0]`: Ressourcentyp weglassen, mit einem Punkt beginnen.

```bash
jq '.code.coding[0]' condition-570762.json
```

✅ **Erwartetes Ergebnis:**

```json
{
  "system": "http://fhir.de/CodeSystem/bfarm/icd-10-gm",
  "version": "2025",
  "code": "570762"
}
```

System und Version passen zur Meldung (`icd-10-gm`, Version `2025`), nur der Code selbst existiert nicht.

🧩 **Was du gerade gesehen hast:** Der Validator sagt dir, **was** nicht stimmt, und mit `expression`, **wo**. Damit kommst du ohne Suchen direkt an das betroffene Feld. Das klappt mit den meisten Meldungen, z. B. `Observation.meta.profile[0]` → `jq '.meta.profile[0]'`. So prüfst du im Alltag eine Meldung nach, bevor du sie an die Datenquelle weitergibst.

### 1.4 Viele Berichte auf einmal

In [Übung 6, Schritt 4.4](exercise-6.md#schritt-4-4) hast du 57 Diagnosen validiert, ihre Berichte liegen in `~/validator/diagnosen/`. 57 Berichte einzeln zu lesen, ist mühsam. Bequemer geht es mit `jq -s`: Es liest alle Berichte auf einmal ein, und du bekommst wieder zuerst einen Überblick:

```bash
cat diagnosen/bericht-*.json \
  | jq -c -s '[.[].issue[].severity] | group_by(.) | map({(.[0]): length}) | add'
```

✅ **Erwartetes Ergebnis:**

```text
{"error":4,"information":57,"warning":116}
```

Welche Meldungen stecken dahinter? Der nächste Befehl fasst gleiche Meldungen zusammen und zählt sie. `[0:200]` kürzt jeden Text auf 200 Zeichen, damit lange Meldungen in eine Zeile passen:

```bash
cat diagnosen/bericht-*.json \
  | jq -r -s '[.[].issue[].details.text[0:200]] | group_by(.) | sort_by(-length) | .[] | "\(length)×  \(.[0])"'
```

✅ **Erwartetes Ergebnis:**

```text
57×  A definition could not be found for Canonical URL 'https://www.medizininformatik-initiative.de/fhir/core/modul-diagnose/StructureDefinition/Diagnose|2024.0.0'
57×  Constraint failed: dom-6: 'A resource should have narrative for robust management' (defined in http://hl7.org/fhir/StructureDefinition/DomainResource) (Best Practice Recommendation)
57×  Profile reference 'https://www.medizininformatik-initiative.de/fhir/core/modul-diagnose/StructureDefinition/Diagnose|2024.0.0' has not been checked because it could not be found, and fetching it resul
2×  Constraint failed: icd-regex: 'In code sind nur gültige ICD-10-Codes ohne Zusätze erlaubt' (defined in http://fhir.de/StructureDefinition/CodingICD10GM)
2×  The code provided (http://fhir.de/CodeSystem/bfarm/icd-10-gm#Z11 U99.0!) was not found in the value set 'MII VS Diagnose ICD-10-GM' (https://www.medizininformatik-initiative.de/fhir/core/modul-diagnos
2×  Unknown code 'Z11 U99.0!' in the CodeSystem 'http://fhir.de/CodeSystem/bfarm/icd-10-gm' version '2021'
```

🧩 **Was du gerade gesehen hast:**

- Aus 177 Meldungen werden sechs Zeilen. Drei Meldungen stehen in **allen** 57 Berichten: zweimal die unbekannte Profilversion `Diagnose|2024.0.0`, dazu `dom-6`. Sie haben eine gemeinsame Ursache, die den ganzen Bestand betrifft. Das ist ein Thema für die Konfiguration oder die Lieferung, nicht für einzelne Diagnosen.
- Drei Meldungen stehen nur **zweimal** da. Das sind die beiden Diagnosen mit dem Code `Z11 U99.0!` aus Übung 6, 4.4: je zwei Fehler und die Warnung `icd-regex`.
- Häufige Meldungen zeigen also systematische Themen (Version, Setup, eine Regel in der ETL-Strecke), seltene meist einzelne fehlerhafte Datensätze. Welche Berichte betroffen sind, findest du mit `grep -l` wie in Übung 6, 4.4, und an der Stelle nachsehen kannst du wie in 1.3.

> 🔍 **Warum kürzen?** Kennt der Validator ein Profil nicht, versucht er, es über seine Canonical-URL aus dem Netz zu laden. Bei den MII-Profilen landet er auf einer Webseite und hängt deren Inhalt an die Meldung an. Bei 57 Anfragen kurz hintereinander antwortete die Seite im Test teils mit „Too many requests“. Dieselbe Meldung hatte deshalb zwei verschiedene Texte, ungekürzt hätte `jq` sie getrennt gezählt.

___

## <a id="schritt-2"></a>🛠️ Schritt 2: Meldungen einordnen

Nicht jede Meldung bedeutet, dass die Daten falsch sind. Ordne jede Meldung aus deinen vier Berichten einer dieser Gruppen zu:

| Gruppe | Frage | Wer muss handeln? |
| --- | --- | --- |
| **Datenfehler** | Ist der Inhalt der Ressource falsch? | Datenquelle bzw. ETL-Strecke |
| **Versionsthema** | Passen Profil- oder Codesystem-Version der Daten zur Version im Validator? | Abstimmung: gegen welche Version wird geprüft? |
| **Grenze des Setups** | Fehlt dem Validator oder dem Terminologieserver etwas (Paket, Codesystem)? | Du selbst: Setup erweitern |
| **Bekannte Meldung** | Steht sie in Tabelle A oben? | Meist niemand |

### 📖 Versionen von Codesystemen und Profilen

Viele Meldungen der Gruppe **Versionsthema** verstehst du erst, wenn du weißt, wo Versionen in FHIR stehen und warum sie sich ändern.

**Codesysteme** ändern sich regelmäßig: Die ICD-10-GM und der OPS erscheinen jährlich, LOINC zweimal im Jahr. Ein Code, der 2023 gültig war, kann 2026 gestrichen oder umbenannt sein. Ein `Coding` kann deshalb die Version mitführen, mit der kodiert wurde:

```json
{
  "system": "http://fhir.de/CodeSystem/bfarm/icd-10-gm",
  "version": "2026",
  "code": "I10.90"
}
```

**Profile** werden ebenfalls versioniert. In `meta.profile` steht die Version hinter einem `|`:

```text
https://www.medizininformatik-initiative.de/fhir/core/modul-diagnose/StructureDefinition/Diagnose|2025.0.0
```

| Situation | Was tun? |
| --- | --- |
| Daten nennen eine ältere Profilversion als der Validator kennt | Vorher festlegen, gegen welche Version geprüft wird, und die passenden Pakete laden (`IG_PARAMS`) |
| Daten wurden mit einer älteren ICD-10-GM-Version kodiert | Terminologieserver mit dieser Version bestücken oder bewusst gegen die aktuelle prüfen |
| Codes haben sich zwischen zwei Versionen geändert | Überleitungstabellen des BfArM für ICD-10-GM und OPS nutzen |

### 🛠️ Aufgabe: Berichte einordnen

- Welche Meldung in `bericht-condition-570762.json` ist ein echter **Datenfehler**?
- Welche Meldungen tauchen in **mehreren** Berichten auf? Zu welcher Gruppe gehören sie?
- Was meldet der Validator zum Laborwert in `bericht-hb.json`, und warum?

<details>
<summary>Lösung</summary>

- `570762` ist kein ICD-10-GM-Code. Der Terminologieserver kennt ihn nicht, der Validator meldet einen ungültigen Code. Das ist ein **Datenfehler** in der Quelle.
- `dom-6` steht in allen Berichten. Das ist eine **bekannte Meldung** (Tabelle A), kein Datenfehler.
- „Profile reference … has not been checked“ steht in den Berichten zu `condition-r51` (`Diagnose|2024.0.0`) und `hb` (`ObservationLab|2025.0.2`): Diese Profilversionen hat der Validator nicht geladen. Das ist ein **Versionsthema**, kein Fehler in den Ressourcen. Bei `hba1c` gilt dieselbe Meldung deinem eigenen Studienprofil, das der Validator gar nicht kennt: eine **Grenze des Setups**. Die Diagnose `570762` nennt `Diagnose|2025.0.0`, die der Validator kennt, deshalb fehlt die Meldung dort.
- Zum Code des Laborwerts meldet der Validator: `A definition for CodeSystem 'http://medic.uksh.de/fhir/CodeSystem/Laborparameter' could not be found, so the code cannot be validated`. Das ist der Hauscode des UKSH. Ein lokales Codesystem kennt ein externer Terminologieserver in der Regel nicht, der Code wurde also nicht geprüft. Falsch ist er deshalb nicht: eine **Grenze des Setups**. Zur Kategorie meldet er, dass LOINC fehlt, sie aber trotzdem gültig ist (`another coding is in the value set`).
- Beim Laborwert erscheint außerdem `None of the codings provided are in the value set 'IdentifierType'` (wie bei `hba1c`). Das MII-Laborprofil würde `OBI` erlauben. Weil der Validator `ObservationLab|2025.0.2` nicht kennt, prüft er nur gegen den FHIR-Basisstandard, und der kennt `OBI` nicht: eine Folge des **Versionsthemas**. `all observations should have a performer` ist wie `dom-6` eine Best-Practice-Empfehlung.

</details>

___

## <a id="nicht-gefunden"></a>🔍 Was der Validator nicht findet

Ein Bericht ohne `error` heißt nicht, dass die Daten fachlich stimmen. Dein eigenes Beispiel aus [Übung 1 · Profil erstellen](exercise-1.md) zeigt das:

Dein Studienprofil legt den LOINC-Code **`4548-4`** fest, und die Beispielinstanz gibt den Wert in **`mmol/mol`** an. Fachlich passt das nicht zusammen:

| LOINC | Bezeichnung | Messgröße | Einheit |
| --- | --- | --- | --- |
| `4548-4` | Hemoglobin A1c/Hemoglobin.total in Blood | Massenanteil | `%` |
| `59261-8` | Hemoglobin A1c/Hemoglobin.total standardized per IFCC-RMP for CDT in Blood | Stoffmengenanteil | `mmol/mol` |

Ein HbA1c-Wert in `mmol/mol` (IFCC) hätte den Code `59261-8` gebraucht. Prüfe das selbst auf [loinc.org](https://loinc.org/4548-4) unter „Property“ und „Example UCUM Units“. Der Fehler steckt bewusst noch in [Übung 1 · Profil erstellen](exercise-1.md), denn kein Werkzeug der Übungen meldet ihn:

- **SUSHI** und der **IG Publisher** prüfen, ob die Instanz zum Profil passt – und das tut sie, denn das Profil selbst enthält die falsche Kombination.
- Der **Validator** prüft, ob `4548-4` ein gültiger LOINC-Code ist und ob `mmol/mol` eine gültige UCUM-Einheit ist. Beides stimmt. Ob Code und Einheit **fachlich zusammenpassen**, prüft er nicht.

> 💡 **Merke:** Validierung prüft die Form, nicht den Sinn. Ob Code, Einheit und Wert zusammenpassen, gehört in fachliche Plausibilitätsprüfungen und in das Review eines Profils.

___

## <a id="schritt-3"></a>💻 Schritt 3: Validierung automatisieren

Im DIZ-Alltag validiert man meist per Skript statt von Hand, z. B. vor jedem Import. Ein einfaches Beispiel liegt in `solution-exercise-7/validate.sh`: Es validiert eine Datei, gibt die Anzahl der Fehler und Warnungen aus und endet mit Exit-Code `1`, sobald ein Fehler auftritt.

```bash
bash ~/tool-kds-sandbox/solution-exercise-7/validate.sh ~/validator/condition-r51.json
bash ~/tool-kds-sandbox/solution-exercise-7/validate.sh ~/validator/condition-570762.json
echo "Exit-Code: $?"
```

✅ **Erwartetes Ergebnis** (Pfade gekürzt, die Fehlerliste dazwischen ausgelassen):

```text
✅ …/validator/condition-r51.json: 0 Fehler, 2 Warnungen
❌ …/validator/condition-570762.json: 2 Fehler, 2 Warnungen
[ … die beiden Fehler aus 1.2 mit code, text und ort … ]
Exit-Code: 1
```

> 💡 Über den Exit-Code kann eine Pipeline (z. B. GitLab CI oder GitHub Actions) entscheiden, ob es weitergeht. Mit der Umgebungsvariable `VALIDATOR_URL` lässt sich ein anderer Validator ansprechen, z. B. `VALIDATOR_URL=http://mein-server:8082 bash validate.sh datei.json`.

___

## <a id="zusammenfassung"></a>🏁 Zusammenfassung und Abschluss

| Aufgabe | Befehl |
| --- | --- |
| Meldungen je Schwere zählen | `jq -c '[.issue[].severity] \| group_by(.) \| map({(.[0]): length}) \| add' bericht.json` |
| Nur Fehler anzeigen | `jq '.issue[] \| select(.severity == "error" or .severity == "fatal")' bericht.json` |
| An der gemeldeten Stelle nachsehen | Pfad aus `expression`, z. B. `jq '.code.coding[0]' ressource.json` |
| Viele Berichte: Meldungen zusammenfassen | `cat bericht-*.json \| jq -r -s '[.[].issue[].details.text[0:200]] \| group_by(.) \| sort_by(-length) \| .[] \| "\(length)×  \(.[0])"'` |
| Datei per Skript prüfen | `bash solution-exercise-7/validate.sh datei.json` |

### Quick-Checkliste

- [ ] Überblick verschafft: Meldungen je Schwere gezählt, bevor du einzelne Berichte liest?
- [ ] Profil wirklich geprüft? Steht „Profile reference … has not been checked“ im Bericht, wurde nur gegen den FHIR-Basisstandard geprüft. Version klären oder mit `profile` prüfen.
- [ ] Jeden `error` an der Stelle aus `expression` in der Ressource nachgesehen?
- [ ] Bei vielen Berichten: Häufige Meldungen als mögliches systematisches Thema geprüft, seltene als mögliche Einzelfälle?
- [ ] Meldungen eingeordnet: Datenfehler, Versionsthema, Grenze des Setups oder bekannte Meldung?
- [ ] „… could not be found, so the code cannot be validated“ heißt **nicht geprüft**, nicht gültig. Ist das für deinen Zweck ausreichend?
- [ ] Fachliche Plausibilität (Code, Einheit, Wert) separat geprüft?
- [ ] Berichte abgelegt (Nachvollziehbarkeit)?

**Abschluss:**

Damit hast du den Weg von FHIR-Daten im DIZ einmal komplett durchlaufen: Du hast ein Profil modelliert ([1 · Profil erstellen](exercise-1.md)), Daten in einen FHIR-Server geladen und abgefragt ([2 · FHIR-Server starten](exercise-2.md), [3 · Musterdaten laden](exercise-3.md), [4 · Daten abfragen](exercise-4.md)), Codes an Terminologieservern geprüft ([5 · Codes prüfen](exercise-5.md)) und Ressourcen gegen die Profile des Kerndatensatzes validiert und die Ergebnisse eingeordnet ([6 · Ressourcen validieren](exercise-6.md), diese Übung).

> 💡 **Feedback willkommen:** War etwas unklar, hat ein Befehl nicht wie beschrieben funktioniert, oder hast du Ideen für weitere Übungen? Eröffne gern ein [Issue auf GitHub](https://github.com/medizininformatik-initiative/tool-kds-sandbox/issues).

___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • **7 · Berichte auswerten**
___
___
