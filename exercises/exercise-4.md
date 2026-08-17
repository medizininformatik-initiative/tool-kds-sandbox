___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • **Exercise 4** • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___

# 🔴 Aufsetzen eines lokalen Terminologieservers

## Einführung & Kontext

In den vorherigen Übungen haben wir gelernt, **FHIR-Ressourcen** in einen Server zu laden und abzufragen. Für eine vollständige Validierung und Kodierung至关重要 sind jedoch ** Terminologien** (Codesysteme) wie ICD-10-GM, SNOMED-CT, LOINC, OPS, ATC, UCUM.

Auch wenn ein FHIR-Server wie **Blaze** über einen integrierten **Terminologieserver** (TermServ) verfügt, müssen die Codesysteme zuerst **heruntergeladen** und **importiert** werden. In dieser Übung richten wir einen lokalen Terminologieserver ein und laden die essentialen Codesysteme für die DIZ-Praxis.

> 💡 **Warum Terminologien?**  
> - **Validierung:** Codes prüfen (z. B. ist `LOINC#4548-4` gültig?)  
> - **Übersetzung:** Zwischen verschiedenen Codiersystemen (z. B. ICD-10-GM → SNOMED)  
> - **Display-Names:** Automatische Anzeige von Code-Beschreibungen  
> - **DIZ-Alltag:** Beim Import, Export und der Datenqualitätssicherung

> 💡 **Hintergrund: MII SU-TermServ**  
> Die MII betreibt einen zentralen **Terminologieservice** (SU-TermServ) für alle DIZe. Für lokale Tests, Offline-Arbeit oder spezifische Versionen ist ein **lokales Setup** dennoch wichtig — und Grundlage für Ex5 (Validation).

---

📋 **Übersicht:**

- [Hintergrund: Terminologien im DIZ](#-hintergrund-terminologien-im-diz)
- [Quellen für Codesysteme](#-quellen-für-codesysteme)
- [Blaze-Termserv einrichten](#-blaze-termserv-einrichten)
- [Codesysteme importieren](#-codesysteme-importieren)
- [Überprüfung & Tests](#-überprüfung--tests)
- [Ausblick & Zusammenfassung](#-ausblick--zusammenfassung)

---

## 💻 Hintergrund: Terminologien im DIZ

### 1.1 Codesysteme für DIZ-Anwendungen

| Codesystem | Quelle | Nutzen im DIZ |
|------------|--------|---------------|
| **ICD-10-GM** | [bfarma](https://terminologien.bfarm.de) | Diagnosekodierung (OPDR, MELD, etc.) |
| **SNOMED-CT** | [NLM](https://www.nlm.nih.gov/healthit/snomedct/) | Klinische Befunde (Observation.code, Condition.code) |
| **LOINC** | [NLM](https://loinc.org) | Laborcodes (Observation.code) |
| **OPS** | [bfarma](https://terminologien.bfarm.de) | Prozeduren (Procedure.code, DiagnosticReport.code) |
| **ATC** | [bfarma](https://terminologien.bfarm.de) | Arzneimittel (Medication.code) |
| **UCUM** | [UCUM.org](https://ucum.org) | Einheiten (valueQuantity.unit) |

> ⚠️ **Versionierung:** Codesysteme werden monatlich/quarterly aktualisiert! Im DIZ-Alltag ist die richtige **Versionierung** kritisch (z. B. LOINC 2.82.0 vs. neuer).

---

## 📥 Quellen für Codesysteme

### 2.1 bfarm (Dekstop-Website & API)

[https://terminologien.bfarm.de](https://terminologien.bfarm.de) bietet Downloads für:

- ICD-10-GM (json, xml)
- LOINC (json, xml, csv)
- OPS (json, xml)
- ATC (json, xml)
- UCUM (json)

**Vorgehen:**
1. Website besuchen → Downloads → Ausgewählte Version auswählen  
2. JSON/XML-Paket herunterladen  
3. Für Blaze-Termserv: JSON-Format nutzen

---

### 2.2 NLM (SNOMED-CT & LOINC)

[https://www.nlm.nih.gov/healthit/snomedct/](https://www.nlm.nih.gov/healthit/snomedct/)

**SNOMED-CT:**
- International Release → RF2 (Compressed Delta-Files)  
- Für Tests: SNOMED-CT International Edition ( miniature / simplified verfügbar)

**LOINC:**
- Direkter Download per API / Webinterface  
- LOINC Table File (TSV) → JSON-Import für TermServ

> 💡 **Hinweis:** SNOMED-CT ist groß (mehrere GB). Für lokale Tests reicht oft die „ miniature Edition“.

---

## 🛠️ Blaze-Termserv einrichten

Blaze bietet einen integrierten Terminologieserver an. Wir erweitern die `docker-compose.yml` von Exercise 1/2 um den TermServ.

### 3.1 docker-compose.yml erweitern

```yaml
services:
  blaze:
    image: "samply/blaze:1.9.0"
    environment:
      JAVA_TOOL_OPTIONS: "-Xmx2g"
    ports:
      - "8080:8080"
    volumes:
      - "blaze-data:/app/data"
    healthcheck:
      test: [ "CMD", "wget", "--spider", "http://localhost:8080/health" ]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
  blaze-term:
    image: "samply/blaze:1.9.0"
    command: ["java", "-Xmx1g", "-jar", "/app/blaze.jar", "terminology"]
    ports:
      - "8081:8080"
    volumes:
      - "blaze-term-data:/app/data"
    healthcheck:
      test: [ "CMD", "wget", "--spider", "http://localhost:8080/health" ]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

volumes:
  blaze-data:
  blaze-term-data:
```

### 3.2 Container starten

```bash
# Server starten
docker compose up -d

# TermServ prüfen
curl -v http://localhost:8081/fhir/metadata
```

---

## 📦 Codesysteme importieren

### 4.1 Import via REST-API

Blaze offeriert einen REST-Endpunkt für den Import (`POST /_import`).

#### ICD-10-GM importieren

```bash
# 1. ICD-10-GM von bfarm herunterladen (z. B. 2025 Version)
wget https://terminologien.bfarm.de/media/downloads/icd-10-gm/icd-10-gm-2025-json.zip

# 2. Entpacken (JSON-Datei)
unzip icd-10-gm-2025-json.zip

# 3. Import via curl (blaze-term:8081)
curl -X POST http://localhost:8081/fhir/\_import \
  -H "Content-Type: application/fhir+json" \
  -d @icd-10-gm-2025.json
```

#### SNOMED-CT importieren (Ausblick)

SNOMED-CT nutzt das **RF2-Format** (Compressed Delta-Files). Für den Import benötigt Blaze ein spezielles Format — alternativ: **SNOMED-CT JSON** (einfacher für Tests).

```bash
# Beispiel für kleine SNOMED-CT JSON (Ausblick)
curl -X POST http://localhost:8081/fhir/\_import \
  -H "Content-Type: application/fhir+json" \
  -d @snomed-ct-minimal.json
```

> ⚠️ **Hinweis:** Der Import kann lange dauern (große Codesysteme). Der Status ist über `GET /_import` abrufbar.

---

### 4.2 Import über MII FHIR Validator (alternative)

Der MII FHIR Validator bringt einen eigenen Terminologieserver mit (ausgestattet mit ICD-10-GM, LOINC, SNOMED-CT).

**Vorteil:** „Out-of-the-box“ mit wichtigen Codesystemen  
**Nachteil:** Weniger flexibel für benutzerdefinierte Versionen

```bash
# Validator starten (Docker)
docker run -p 8082:8080 \
  -v $(pwd)/validator-data:/data \
  mii/fhir-validator:latest
```

> 💡 **Ex5** geht detailliert auf den MII Validator ein — hier nur als Hinweis.

---

## ✅ Überprüfung & Tests

### 5.1 Codesysteme abfragen

```bash
# Alle geladenen Codesysteme
curl -s "http://localhost:8081/fhir/CodeSystem" | jq '.entry[].resource | {id: .id, url: .url, version: .version, name: .name}'

# ICD-10-GM prüfen
curl -s "http://localhost:8081/fhir/CodeSystem?name=icd-10-gm" | jq '.entry[].resource | {url, version, count: .concept | length}'

# LOINC prüfen
curl -s "http://localhost:8081/fhir/CodeSystem?name=loinc" | jq '.entry[].resource | {url, version}'
```

### 5.2 Code-Bestätigung testen

```bash
# Code `4548-4` (LOINC) prüfen
curl -s "http://localhost:8081/fhir/ValueSet/\$expand?url=http://loinc.org&code=4548-4" | jq '.expansion.contains[0]'

# ICD-10-GM Code `I10` (Essentielle Hypertonie) prüfen
curl -s "http://localhost:8081/fhir/ValueSet/\$expand?url=http://fhir.de/CodeSystem/bfarm/icd-10-gm&code=I10" | jq '.expansion.contains[0]'
```

---

## 🏁 Ausblick & Zusammenfassung

### Zusammenfassung

| Schritt | Kommando |
|---------|----------|
| **Blaze-Termserv starten** | `docker compose up -d blaze-term` |
| **Codesystem herunterladen** | `wget https://terminologien.bfarm.de/...` |
| **Codesystem importieren** | `curl -X POST http://localhost:8081/fhir/\_import -d@code.json` |
| **Import prüfen** | `curl http://localhost:8081/fhir/CodeSystem` |
| **Code validieren** | `curl http://localhost:8081/fhir/ValueSet/\$expand?...` |

### Ausblick

- **Ex5:** Validierung — prüfen, ob Ressourcen/Profile mit den geladenen Codesystemen übereinstimmen  
- **Ex6:** Validierungsreport interpretieren (Warnings, Errors)  

### Zukünftige Erweiterungen

- **Automatisierung:** Import-Script für monatliche Updates (Cronjob)  
- **Zentrale TermServ-Verwaltung:** MII SU-TermServ für alle DIZe  
- **Versionierung:** Historie der Codesysteme (mehrere Versionen parallel)  

---

**Nächste Schritte:**  
- Startere Blaze-Termserv und importiere ICD-10-GM + LOINC  
- Teste die Code-Validierung über die REST-API  
- Bereite dich auf Ex5 (Validator) vor

___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • **Exercise 4** • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___