___
___
[Prerequisites](prerequisites.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • **Exercise 6** • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
___
___

# 🟣 Nutzen eines FHIR Validators

**Nächste Schritte:**  

- Starte den Validator
- Validiere die Ressourcen aus Ex1/Ex3  
- Bereite dich auf Ex7 (Bericht-Interpretation) vor

___

## Einführung & Kontext

Nachdem wir in [Exercise 5](exercise-5.md) gelernt haben, **Codesysteme lokal zu laden**, ist der nächste Schritt die **Validierung** unserer FHIR-Ressourcen und -Profile.

Der **MII FHIR Validator** ist ein wichtiger Bestandteil für die MII-Infrastruktur und dient dazu, sicherzustellen, dass alle Daten, die in die DIZe eingespeist werden, **konform** mit den definierten Profilen und Codesystemen sind.

> 💡 **Warum Validierung?**  
>
> - **Datenqualität:** Fehler frühzeitig erkennen (falsche Codes, fehlende Pflichtfelder)  
> - **Standortübergreifende Konsistenz:** Alle DIZe(validieren auf demselben Standard)  
> - **Audit & Compliance:** Nachweisbarkeit der Datenqualität  
> - **DIZ-Alltag:** Vor dem Export, Integration, oder bei der Datenbereinigung

Ob eine FHIR-Ressource formal in Ordnung ist, lässt sich schnell und ohne Installation prüfen: Webtools wie fhirtoolbox.com laufen im Browser, finden Tippfehler, falsche Datentypen oder fehlende Pflichtfelder und liefern sofort Rückmeldung. Auch SUSHI, der Compiler für FHIR Shorthand (FSH), weist beim Build auf Fehler im FSH-Quelltext hin, etwa auf Syntaxfehler oder unbekannte Elementpfade. Das reicht aber nur für die Struktur. Ob ein Code wirklich existiert, zum vorgeschriebenen ValueSet gehört und ein passendes Display hat, oder ob die Ressource das richtige Profil erfüllt, kann ein solches Tool nicht beurteilen. Dafür braucht es einen Validator, der die Profile kennt, und einen Terminologieserver, der die Codes prüft. Erst diese Kombination zeigt, ob eine Ressource nicht nur "gut aussieht", sondern fachlich und technisch korrekt ist. In dieser Übung lernst du beides kennen und siehst, welche Fehler welches Werkzeug findet.

> 💡 **Ausblick:** In [Exercise 7](exercise-7.md) lernst du, die Validierungsberichte **zu interpretieren** und typische Errors zu beheben.

___

📋 **Übersicht:**

- [Hintergrund: FHIR-Validation](#-hintergrund-fhir-validation)
- [Validator-Umgebung einrichten](#validator-umgebung-einrichten)
- [Validation-Beispiele](#-validation-beispiele)
- [Validation über CLI](#-validation-über-cli)
- [Zusammenfassung & Ausblick](#-zusammenfassung--ausblick)

___

# Platzhalter/TODO - Reihenfolge, Pacing, Praktischer Anteil:

## Validierungswerkzeuge im Vergleich - work in progress

| | `$validate` / `$validate-code` | IG Publisher | HL7/HAPI Validator (CLI) | MII FHIR Validator | gematik Referenzvalidator |
|---|---|---|---|---|---|
| **Prüft** | Einzelne Ressource bzw. einzelnen Code | Ganzes IG inkl. Beispiele | Beliebige Ressourcen gegen Profile | Ressourcen gegen MII-IGs | Ressourcen für TI-Anwendungen (z. B. E-Rezept, ISiK) |
| **Aufruf** | REST-Anfrage an Server | Build-Prozess | `java -jar validator_cli.jar` | HTTP: `POST :8080/validateResource` | Java-Bibliothek / Anwendung |
| **Profile/IGs** | Auf dem Server geladen | Aus dem IG und seinen Abhängigkeiten | Per Parameter wählbar | MII-IGs vorinstalliert, weitere per `IG_PARAMS` | Fest vorgegeben, Pakete mitgeliefert |
| **Terminologie** | Der angefragte Server | tx.fhir.org (änderbar) | tx.fhir.org oder eigener Server | Konfigurierbar (`TX_SERVER`): Blaze lokal, MII Ontoserver oder anderer | Pakete enthalten |
| **Setup** | Keins | IG-Projekt + Publisher | Java + JAR | Docker Compose | Maven/Java |
| **Offline** | Nur mit lokalem Server | Nur mit lokalem tx-Server | Möglich | Möglich (Cache im Image, Blaze lokal) | Ja (Pakete eingebaut) |
| **Typischer Einsatz** | Einstieg, Debugging | IG-Autoren | Entwickler, CI | MII-Standorte, ETL-Entwicklung | Hersteller im TI-Umfeld |
| **Ausgabe** | OperationOutcome | QA-Report | Konsole / OperationOutcome | OperationOutcome | OperationOutcome |

**Technische Basis:** MII-Validator, HAPI-CLI und gematik-Referenzvalidator beruhen auf demselben HL7/HAPI-Validator-Code. Sie unterscheiden sich in Konfiguration, Paketen und Einsatzzweck.

## Validierungswerkzeuge im Vergleich

Es gibt nicht *den einen* FHIR-Validator, sondern mehrere Werkzeuge für unterschiedliche Zwecke. Die meisten davon nutzen im Kern denselben HL7/HAPI-Validator-Code. Sie unterscheiden sich vor allem darin, **was** sie prüfen (einzelne Ressource, einzelner Code oder ein ganzes IG), **wie** man sie aufruft (REST, Kommandozeile, Build-Prozess) und **wie sie konfiguriert sind** (Profile, Terminologieserver, Offline-Betrieb). Die Tabelle hilft dir bei der Wahl: Für den schnellen Einstieg eignen sich `$validate` und `$validate-code`. Für IG-Autoren ist es der IG Publisher. Für die praktische Arbeit in der MII nutzt du den MII FHIR Validator, und im TI-Umfeld gilt der gematik Referenzvalidator.

### Strukturelle Validierung vs. Conformance-Validierung

| Prüfebene | Strukturell (z. B. fhirtoolbox.com) | Conformance (HL7/HAPI Validator, IG Publisher, MII-Validator) |
|---|---|---|
| **Frage** | Ist das gültiges FHIR-JSON? | Entspricht die Ressource dem Standard und den Profilen? |
| **Syntax / Datentypen** | ✅ | ✅ |
| **Pflichtelemente / Kardinalität** | Teilweise (nur ausgewählte Ressourcen) | ✅ Alle Elemente laut Profil |
| **Invarianten (FHIRPath)** | ❌ | ✅ |
| **Profile / IGs / Slicing** | ❌ | ✅ |
| **Codes in fest eingebauten Listen** (z. B. `gender`) | ✅ | ✅ |
| **Code existiert im CodeSystem?** | ❌ | ✅ via Terminologieserver (`$validate-code`) |
| **Code gehört zum gebundenen ValueSet?** | ❌ | ✅ via Terminologieserver |
| **Display passt zum Code?** | ❌ | ✅ via Terminologieserver |
| **Terminologieserver nötig?** | Nein | Ja (tx.fhir.org, Blaze, Ontoserver, FHIRsmith …) |
| **Typischer Einsatz** | Schneller Check beim Schreiben | Vor Release, in CI, bei Konformitätsaussagen |

___

## 💻 Hintergrund: FHIR-Validation

### 1.1 Welche Validierungen gibt es?

| Ebene | Prüfung | Ziel |
| ----- | ------- | ---- |
| **Ressourcenebene** | Struktur & Pflichtfelder | Ist die Ressource syntaktisch korrekt? |
| **Profil Ebene** | Profil-Constraint | Erfüllt die Ressource alle Profil-Regeln? |
| **Codesystem-Ebene** | Code-Validität | Ist der verwendete Code im Codesystem enthalten? |
| **Referenzielle Integrität** | Referenzen | Verweist die Ressource auf gültige Zielressourcen? |

> ⚠️ **Hinweis:** FHIR-Validator prüft **nicht** fachliche Kontexte (z. B. „Ist ein Laborwert plausibel?“) — das muss die Geschäftslogik der Anwendung prüfen.

___

### 1.2 Validierungsbericht-Struktur

Ein Validierungsbericht enthält typischerweise:

| Feld | Inhalt |
| ---- | ------ |
| **severity** | `error` / `warning` / `information` / `fatal` |
| **code** | `invalid` / `structure` / `required` / `binding` |
| **details` | Beschreibung des Issues (Text + Link zur HL7-Spezifikation) |
| **location` | XML/JSON-Pfad zur fehlerhaften Zeile |

___

## <a id="validator-umgebung-einrichten"></a>🛠️ Validator-Umgebung einrichten

### 2.1 MII FHIR Validator als Docker-Container starten

```bash
# Validator starten (mit lokal geladenen Codesystemen)
docker run -p 8082:8080 \
  -v $(pwd)/validator-data:/app/data \
  -d \
  --name mii-validator \
  mii/fhir-validator:latest

# Status prüfen
docker ps | grep mii-validator
```

> 💡 **Hinweis:** Der Validator läuft standardmäßig auf `http://localhost:8082`.

___

### 2.2 Validator-Configuration (optional)

Der Validator kann über eine `config.json` konfiguriert werden:

```json
{
  "validator": {
    "codesystems": ["LOINC", "SNOMED-CT", "ICD-10-GM"],
    "profiles": ["http://fhir.de/StructureDefinition/labor-befund"]
  },
  "output": {
    "format": "json",
    "includeExplanations": true
  }
}
```

___

## ✅ Validation-Beispiele

### 3.1 Einzelne Ressource validieren

```bash
# Beispiel: Eine Labor-Observation validieren
curl -X POST http://localhost:8082/fhir/\$validate \
  -H "Content-Type: application/fhir+json" \
  -d @path/to/observation.json | jq
```

**Erwartetes Ergebnis:**

```json
{
  "resourceType": "OperationOutcome",
  "issue": [
    {
      "severity": "information",
      "code": "informational",
      "details": {
        "text": "Validation successful"
      }
    }
  ]
}
```

___

### 3.2 Ressource gegen Profil validieren

```bash
# Beispiel: Observation gegen MII Labor-Profil validieren
curl -X POST "http://localhost:8082/fhir/\$validate?profile=http://fhir.de/StructureDefinition/labor-befund" \
  -H "Content-Type: application/fhir+json" \
  -d @path/to/observation.json | jq '.issue[] | {severity, code, details}'
```

___

### 3.3 Beispieldaten validieren (aus Ex3)

```bash
# Validiere das gesamte Bundle (UKSH-Musterdatenspende)
curl -X POST http://localhost:8082/fhir/\$validate \
  -H "Content-Type: application/fhir+json" \
  --data @bundle-repaired.json | jq '.issue | length'
```

> ⚠️ **Hinweis:** Bei großen Bundles (8.400+ Ressourcen) kann die Validierung lange dauern. Für Tests: Bundle teilen.

___

## 💻 Validation über CLI

### 4.1 Validator CLI (Java JAR)

Download des Validator-Publishers (siehe [MII FHIR Validator Repo](https://github.com/medizininformatik-initiative/mii-fhir-validator)).

```bash
# Validator JAR herunterladen
curl -L https://github.com/medizininformatik-initiative/mii-fhir-validator/releases/latest/download/fhir-validator.jar -o fhir-validator.jar

# Einzelne Ressource validieren
java -jar fhir-validator.jar \
  -i observation.json \
  -p http://fhir.de/StructureDefinition/labor-befund \
  -o output.json
```

___

### 4.2 Validation mit Codesystem-Check

```bash
# Codesystem-Code prüfen (z. B. LOINC#4548-4)
java -jar fhir-validator.jar \
  -code-system http://loinc.org \
  -code 4548-4 \
  -version 2.82.0
```

___

## 🏁 Zusammenfassung & Ausblick

### Zusammenfassung

| Schritt | Kommando |
| ------- | -------- |
| **Validator starten** | `docker run -p 8082:8080 mii/fhir-validator:latest` |
| **Ressource validieren** | `curl -X POST http://localhost:8082/fhir/\$validate -d@ressource.json` |
| **Profil-Validierung** | `curl -X POST .../\$validate?profile=...` |
| **CLI-Validierung** | `java -jar fhir-validator.jar -i input.json` |

### Ausblick

- **Ex7:** Validierungsberichte interpretieren (Errors, Warnings, häufige Issues)  
- **DIZ-Alltag:** Validation vor Export, Import, oder bei Datenanfragen  

### Tipps

- ✅ **Regelmäßig validieren:** Nicht erst am Ende — bei jeder Ressourcenerschaffung  
- ✅ **Frühzeitig prüfen:** „Fail fast“ — Fehler direkt im Build-Prozess (CI/CD)  
- ✅ **Documentation:** Validierungsberichte archivieren (Audit!)  

___
___
[Prerequisites](prerequisites.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • **Exercise 6** • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
___
___
