___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [Übung 1](exercise-1.md) • [Übung 2](exercise-2.md) • [Übung 3](exercise-3.md) • [Übung 4](exercise-4.md) • [Übung 5](exercise-5.md) • [Übung 6](exercise-6.md) • **Übung 7**
___
___

# 🟤 Interpretieren von Ergebnissen

**Nächste Schritte:**

- Verstehe den Aufbau eines Validierungsberichts (`OperationOutcome`)
- Filtere und zähle die Meldungen deiner Berichte aus [Übung 6](exercise-6.md) mit `jq`
- Ordne Meldungen ein: Datenfehler, Versionsthema oder Grenze des Setups?
- Lerne, was ein Validator **nicht** findet

In [Übung 6](exercise-6.md) hast du Ressourcen mit dem MII FHIR Validator geprüft. Die Antwort war jedes Mal ein **`OperationOutcome`**, die „Sprache“, in der FHIR Ergebnisse und Fehler meldet.

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
| *Unknown code 'X' in the CodeSystem 'Y'* | Code existiert im CodeSystem nicht | Tippfehler, falsche Version, falsches System | Code per `$lookup` oder `$validate-code` prüfen ([Übung 5](exercise-5.md)) |
| *None of the codings provided are in the value set 'X'* | Code liegt nicht im gebundenen ValueSet | Falscher Code oder falsches System | ValueSet per `$expand` ansehen ([Übung 5](exercise-5.md)) |
| *CodeSystem 'X' could not be found, so the code cannot be validated* | Terminologieserver kennt das System nicht | System nicht geladen oder lizenzpflichtig (LOINC, SNOMED CT) | Inhalt laden oder anderen Terminologieserver verwenden |
| *Unable to validate code … terminology service … error / unavailable* | Terminologieserver nicht erreichbar oder Fehler | Netzwerk, Zertifikat, Server gestoppt | `TX_SERVER` und Erreichbarkeit prüfen |
| *Reference … could not be resolved* | Referenzierte Ressource nicht gefunden | Fehlende Ressource im Bundle | Ressource ergänzen oder Referenz anpassen |
| *URL … does not resolve* (bei Beispiel-URLs) | Beispiel-Domain nicht erreichbar | Test-Canonicals wie `http://example.org` | Beim CLI: `-allow-example-urls true` |
| *Unknown element / Unrecognised property* | Element existiert nicht in der Ressource | Tippfehler, falsche FHIR-Version | Schreibweise und Version prüfen |
| *A code should come from this value set …* (Warning) | Extensible Binding verletzt | Code außerhalb des ValueSets | Ggf. akzeptabel, im Profil prüfen |

___

## <a id="schritt-1"></a>💻 Schritt 1: Berichte speichern und auswerten

> ⚠️ **Voraussetzung:** Der Validator aus [Übung 6](exercise-6.md) läuft auf Port 8082, und in `~/validator` liegen die Dateien `hba1c.json`, `condition-570762.json`, `condition-c20.json` und `hb.json`.

Speichere zuerst die Berichte als Dateien. So musst du nicht bei jeder Auswertung neu validieren:

```bash
cd ~/validator
for f in hba1c condition-570762 condition-c20 hb; do
  curl -s -X POST http://localhost:8082/validateResource \
    -H "Content-Type: application/fhir+json" \
    --data @$f.json > bericht-$f.json
done
ls bericht-*.json
```

### 1.1 Meldungen je Schwere zählen

```bash
for f in bericht-*.json; do
  echo "$f: $(jq -c '[.issue[].severity] | group_by(.) | map({(.[0]): length}) | add' $f)"
done
```

<!-- TODO beim Test: erwartete Ausgabe eintragen -->

### 1.2 Nur die Fehler anzeigen

```bash
jq '[.issue[] | select(.severity == "error" or .severity == "fatal") | {code, text: (.details.text // .diagnostics), ort: (.expression // .location)[0]}]' bericht-condition-570762.json
```

### 1.3 Gleiche Meldungen zusammenfassen

Bei vielen Ressourcen wiederholen sich Meldungen. Gruppiert nach Text siehst du, welche Probleme am häufigsten vorkommen:

```bash
cat bericht-*.json \
  | jq -s '[.[].issue[] | (.details.text // .diagnostics)] | group_by(.) | map({anzahl: length, meldung: .[0]}) | sort_by(-.anzahl)'
```

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
- Welche Meldungen tauchen in **allen** Berichten der Musterdaten auf? Zu welcher Gruppe gehören sie?
- Was meldet der Validator zum Laborwert in `bericht-hb.json`, und warum?

<details>
<summary>Lösung</summary>

- `570762` ist kein ICD-10-GM-Code. Der Terminologieserver kennt ihn nicht, der Validator meldet einen ungültigen Code. Das ist ein **Datenfehler** in der Quelle.
- Meldungen zu `meta.profile` betreffen alle Musterdaten: Die Ressourcen nennen Profilversionen von 2024/2025, der Validator ist mit den Paketen von 2026 konfiguriert. Das ist ein **Versionsthema**, kein Fehler in den einzelnen Ressourcen.
- Der Laborwert ist mit LOINC kodiert. Ist LOINC auf deinem Terminologieserver nicht geladen (z. B. beim eigenen FHIRsmith aus [Übung 6, Schritt 1a](exercise-6.md#schritt-1a)), kann der Code nicht geprüft werden. Das ist eine **Grenze des Setups**. Kennt der Server LOINC, sollte hier keine Meldung zum Code erscheinen.

<!-- TODO beim Test: Lösung mit den tatsächlichen Meldungstexten abgleichen -->

</details>

___

## <a id="nicht-gefunden"></a>🔍 Was der Validator nicht findet

Ein Bericht ohne `error` heißt nicht, dass die Daten fachlich stimmen. Dein eigenes Beispiel aus [Übung 1](exercise-1.md) zeigt das:

Dein Studienprofil legt den LOINC-Code **`4548-4`** fest, und die Beispielinstanz gibt den Wert in **`mmol/mol`** an. Fachlich passt das nicht zusammen:

| LOINC | Bezeichnung | Messgröße | Einheit |
| --- | --- | --- | --- |
| `4548-4` | Hemoglobin A1c/Hemoglobin.total in Blood | Massenanteil | `%` |
| `59261-8` | Hemoglobin A1c/Hemoglobin.total standardized per IFCC-RMP for CDT in Blood | Stoffmengenanteil | `mmol/mol` |

Ein HbA1c-Wert in `mmol/mol` (IFCC) hätte den Code `59261-8` gebraucht. Prüfe das selbst auf [loinc.org](https://loinc.org/4548-4) unter „Property“ und „Example UCUM Units“. Der Fehler steckt bewusst noch in [Übung 1](exercise-1.md), denn kein Werkzeug der Übungen meldet ihn:

- **SUSHI** und der **IG Publisher** prüfen, ob die Instanz zum Profil passt – und das tut sie, denn das Profil selbst enthält die falsche Kombination.
- Der **Validator** prüft, ob `4548-4` ein gültiger LOINC-Code ist und ob `mmol/mol` eine gültige UCUM-Einheit ist. Beides stimmt. Ob Code und Einheit **fachlich zusammenpassen**, prüft er nicht.

> 💡 **Merke:** Validierung prüft die Form, nicht den Sinn. Ob Code, Einheit und Wert zusammenpassen, gehört in fachliche Plausibilitätsprüfungen und in das Review eines Profils.

___

## <a id="schritt-3"></a>💻 Schritt 3: Validierung automatisieren

Im DIZ-Alltag validiert man nicht von Hand, sondern per Skript, z. B. vor jedem Import. Ein einfaches Beispiel liegt in `solution-exercise-7/validate.sh`: Es validiert eine Datei, gibt die Anzahl der Fehler und Warnungen aus und endet mit Exit-Code `1`, sobald ein Fehler auftritt.

```bash
bash ~/tool-kds-sandbox/solution-exercise-7/validate.sh ~/validator/condition-c20.json
bash ~/tool-kds-sandbox/solution-exercise-7/validate.sh ~/validator/condition-570762.json
echo "Exit-Code: $?"
```

> 💡 Über den Exit-Code kann eine Pipeline (z. B. GitLab CI oder GitHub Actions) entscheiden, ob es weitergeht. Mit der Umgebungsvariable `VALIDATOR_URL` lässt sich ein anderer Validator ansprechen, z. B. `VALIDATOR_URL=http://mein-server:8082 bash validate.sh datei.json`.

___

## <a id="zusammenfassung"></a>🏁 Zusammenfassung und Abschluss

| Aufgabe | Befehl |
| --- | --- |
| Meldungen je Schwere zählen | `jq '[.issue[].severity] \| group_by(.) \| map({(.[0]): length}) \| add' bericht.json` |
| Nur Fehler anzeigen | `jq '[.issue[] \| select(.severity == "error")]' bericht.json` |
| Meldungen gruppieren | `jq -s '[.[].issue[] \| .details.text] \| group_by(.) \| map({anzahl: length, meldung: .[0]})'` |
| Datei per Skript prüfen | `bash solution-exercise-7/validate.sh datei.json` |

### Quick-Checkliste

- [ ] `error` = 0? Wenn nein: Ursache einordnen und beheben
- [ ] Warnungen gelesen? Akzeptabel oder Handlungsbedarf?
- [ ] Profil- und Codesystem-Versionen der Daten passen zur Konfiguration des Validators?
- [ ] Fachliche Plausibilität separat geprüft?
- [ ] Bericht abgelegt (Nachvollziehbarkeit)?

**Abschluss:**

Damit hast du den Weg von FHIR-Daten im DIZ einmal komplett durchlaufen: Du hast ein Profil modelliert ([Übung 1](exercise-1.md)), Daten in einen FHIR-Server geladen und abgefragt ([Übungen 2–4](exercise-2.md)), Codes an Terminologieservern geprüft ([Übung 5](exercise-5.md)) und Ressourcen gegen die Profile des Kerndatensatzes validiert und die Ergebnisse eingeordnet ([Übungen 6](exercise-6.md) und 7).

___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [Übung 1](exercise-1.md) • [Übung 2](exercise-2.md) • [Übung 3](exercise-3.md) • [Übung 4](exercise-4.md) • [Übung 5](exercise-5.md) • [Übung 6](exercise-6.md) • **Übung 7**
___
___
