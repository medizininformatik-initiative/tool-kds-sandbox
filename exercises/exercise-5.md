___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • **Exercise 5** • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___

# 🟣 Nutzen des MII FHIR Validators

## Einführung & Kontext

Nachdem wir in [Exercise 4](exercise-4.md) gelernt haben, **Codesysteme lokal zu laden**, ist der nächste Schritt die **Validierung** unserer FHIR-Ressourcen und -Profile.

Der **MII FHIR Validator** ist ein wichtiger Bestandteil für die MII-Infrastruktur und dient dazu, sicherzustellen, dass alle Daten, die in die DIZe eingespeist werden, **konform** mit den definierten Profilen und Codesystemen sind.

> 💡 **Warum Validierung?**  
> - **Datenqualität:** Fehler frühzeitig erkennen (falsche Codes, fehlende Pflichtfelder)  
> - **Standortübergreifende Konsistenz:** Alle DIZe(validieren auf demselben Standard)  
> - **Audit & Compliance:** Nachweisbarkeit der Datenqualität  
> - **DIZ-Alltag:** Vor dem Export, Integration, oder bei der Datenbereinigung

> 💡 **Ausblick:** In [Exercise 6](exercise-6.md) lernst du, die Validierungsberichte **zu interpretieren** und typische Errors zu beheben.

---

📋 **Übersicht:**

- [Hintergrund: FHIR-Validation](#-hintergrund-fhir-validation)
- [Validator-Umgebung einrichten](#-validator-umgebung-einrichten)
- [Validation-Beispiele](#-validation-beispiele)
- [Validation über CLI](#-validation-über-cli)
- [Zusammenfassung & Ausblick](#-zusammenfassung--ausblick)

---

## 💻 Hintergrund: FHIR-Validation

### 1.1 Welche Validierungen gibt es?

| Ebene | Prüfung | Ziel |
|-------|---------|------|
| **Ressourcenebene** | Struktur & Pflichtfelder | Ist die Ressource syntaktisch korrekt? |
| **Profil Ebene** | Profil-Constraint | Erfüllt die Ressource alle Profil-Regeln? |
| **Codesystem-Ebene** | Code-Validität | Ist der verwendete Code im Codesystem enthalten? |
| **Referenzielle Integrität** | Referenzen | Verweist die Ressource auf gültige Zielressourcen? |

> ⚠️ **Hinweis:** FHIR-Validator prüft **nicht** fachliche Kontexte (z. B. „Ist ein Laborwert plausibel?“) — das muss die Geschäftslogik der Anwendung prüfen.

---

### 1.2 Validierungsbericht-Struktur

Ein Validierungsbericht enthält typischerweise:

| Feld | Inhalt |
|------|--------|
| **severity** | `error` / `warning` / `information` / `fatal` |
| **code** | `invalid` / `structure` / `required` / `binding` |
| **details` | Beschreibung des Issues (Text + Link zur HL7-Spezifikation) |
| **location` | XML/JSON-Pfad zur fehlerhaften Zeile |

---

## 🛠️ Validator-Umgebung einrichten

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

---

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

---

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

---

### 3.2 Ressource gegen Profil validieren

```bash
# Beispiel: Observation gegen MII Labor-Profil validieren
curl -X POST "http://localhost:8082/fhir/\$validate?profile=http://fhir.de/StructureDefinition/labor-befund" \
  -H "Content-Type: application/fhir+json" \
  -d @path/to/observation.json | jq '.issue[] | {severity, code, details}'
```

---

### 3.3 Beispieldaten validieren (aus Ex2)

```bash
# Validiere das gesamte Bundle (UKSH-Musterdatenspende)
curl -X POST http://localhost:8082/fhir/\$validate \
  -H "Content-Type: application/fhir+json" \
  --data @bundle-repaired.json | jq '.issue | length'
```

> ⚠️ **Hinweis:** Bei großen Bundles (8.400+ Ressourcen) kann die Validierung lange dauern. Für Tests: Bundle teilen.

---

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

---

### 4.2 Validation mit Codesystem-Check

```bash
# Codesystem-Code prüfen (z. B. LOINC#4548-4)
java -jar fhir-validator.jar \
  -code-system http://loinc.org \
  -code 4548-4 \
  -version 2.82.0
```

---

## 🏁 Zusammenfassung & Ausblick

### Zusammenfassung

| Schritt | Kommando |
|---------|----------|
| **Validator starten** | `docker run -p 8082:8080 mii/fhir-validator:latest` |
| **Ressource validieren** | `curl -X POST http://localhost:8082/fhir/\$validate -d@ressource.json` |
| **Profil-Validierung** | `curl -X POST .../\$validate?profile=...` |
| **CLI-Validierung** | `java -jar fhir-validator.jar -i input.json` |

### Ausblick

- **Ex6:** Validierungsberichte interpretieren (Errors, Warnings, häufige Issues)  
- **DIZ-Alltag:** Validation vor Export, Import, oder bei Datenanfragen  

### Tipps

- ✅ **Regelmäßig validieren:** Nicht erst am Ende — bei jeder Ressourcenerschaffung  
- ✅ **Frühzeitig prüfen:** „Fail fast“ — Fehler direkt im Build-Prozess (CI/CD)  
- ✅ **Documentation:** Validierungsberichte archivieren (Audit!)  

---

**Nächste Schritte:**  
- Starte den Validator (Docker)  
- Validiere die Ressourcen aus Ex0/Ex2  
- Bereite dich auf Ex6 (Bericht-Interpretation) vor

___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • **Exercise 5** • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___