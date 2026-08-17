___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • **Exercise 7**
___
___

# ⚫ Ausblick: Sonstiges

## Einführung & Kontext

In den vorherigen Übungen hast du gelernt, **FHIR-Profile zu definieren**, **Daten in den Server zu laden**, **Abfragen durchzuführen**, **Terminologien zu laden** und **Ressourcen zu validieren**.

In dieser letzten Übung schauen wir auf **Alternative Werkzeuge**, **Versionierung**, **Lizenzen** und **Zukunftsausblick** — ohne praktische Übung, aber mit dem nötigen Kontext, um im DIZ-Alltag informierte Entscheidungen zu treffen.

---

📋 **Übersicht:**

- [Alternative Werkzeuge](#-alternative-werkzeuge)
- [Versionierung von Codesystemen](#-versionierung-von-codesystemen)
- [Lizenzen](#-lizenzen)
- [Zukunft: Erweiterungen](#-zukunft-erweiterungen)
- [Abschluss](#-zusammenfassung)

---

## 🔧 Alternative Werkzeuge

### 1.1 Terminologieserver

| Server | Vorteile |  Einsatz |
|--------|----------|----------|
| **Blaze TermServ** (MII-Standard) | Einfach, integriert mit Blaze, Open Source | DIZ-Standard |
| **HAPI FHIR** | Reife Implementation, viele Features, großes Community | Alt-DIZ, migrierte Systeme |
| **SMART on FHIR** | App-Plattform | Apps, externe Integration |
| **MII SU-TermServ** (zentral) | Aktuelle Codes, support durch MII | Alle DIZe (zusätzlich zu lokal) |

---

### 1.2 Validierungsservices

| Service | Vorteile |
|---------|----------|
| **MII FHIR Validator** (lokal) | Konformität zu MII-Standards, ICD-10-GM/LOINC/SNOMED |
| **HAPI Validator** | Universell, alle FHIR-Versionen |
| **Firely Validator** | Schnell, modern, CLI-Tool |
| **Simplifier.net** (Web) | Visuell, gute UX, Community-Profiles |

---

### 1.3 FHIR-Server

| Server | Vorteile |
|--------|----------|
| **Blaze** (MII-Standard) | Einfach, Open Source, gut dokumentiert |
| **HAPI FHIR** | Reif, viele Erweiterungen (web UI, full-text) |
| **AWS HealthLake** | Skalierbar, AWS-Integration |
| **Azure FHIR Service** | Azure-Integration, Managed |

---

## 🔢 Versionierung von Codesystemen

### 2.1 Warum Versionierung?

| Szenario | Problem ohne Versionierung |
|----------|----------------------------|
| **Neuer LOINC-Code** | Alte Daten mit altem Code bleiben gültig, neue mit neuem Code — aber wie kombinieren? |
| **ICD-10-GM Update** | Diagnosen im Jahr 2024 mit ICD-10-GM 2024, 2025 mit 2025 — wie Abfragen? |
| **Audit & Nachvollziehbarkeit** | Wie weiß man, welcher Code zum Zeitpunkt X verwendet wurde? |

---

### 2.2 FHIR-Approach: `code.system` + `code.version`

In FHIR kannst Du eine **Version** angucken:

```json
{
  "code": {
    "coding": [
      {
        "system": "http://loinc.org",
        "code": "4548-4",
        "version": "2.82.0",
        "display": "Hemoglobin A1c/Hemoglobin.total in Blood"
      }
    ]
  }
}
```

---

### 2.3 Praxis-Tipps

| Praxis-Problem | Lösung |
|----------------|--------|
| **Mehrere Versionen parallel** | Verwende `code.version` in allen Ressourcen |
| **Versions-Migration** | Update-Skripte (z. B. `4548-4|2.81.0` → `4548-4\|2.82.0`) |
| **Validierung mit alter Version** | Validator mit `?version=2.81.0` aufrufen (falls supported) |

> ⚠️ **Hinweis:** Nicht alle Validatoren unterstützen `code.version`. Prüfe vor dem Einsatz!

---

## 📜 Lizenzen

### 3.1 Codesystem-Lizenzen im Überblick

| Codesystem | Lizenz | Kosten | Download |
|------------|--------|--------|----------|
| **LOINC** | Apache 2.0 (ab 2025) | Kostenlos | [loinc.org](https://loinc.org) |
| **SNOMED-CT** | SNOMED International License | Kosten (Country License) | [snomed.org](https://snomed.org) |
| **ICD-10-GM** | public domain (BFarm) | Kostenlos | [terminologien.bfarm.de](https://terminologien.bfarm.de) |
| **OPS** | public domain (BFarm) | Kostenlos | [terminologien.bfarm.de](https://terminologien.bfarm.de) |
| **UCUM** | BSD 3-Clause | Kostenlos | [ucum.org](https://ucum.org) |

> 💡 **Hinweis:** SNOMED-CT ist in Deutschland **kostenpflichtig** (via BIH/DAISM). Im Rahmen der MII sollten die meisten DIZ inzwischen über eine SNOMED CT-Lizenz verfügen.

---

### 3.2 Lizenzkompatibilität

- **Apache 2.0 + MIT + BSD** → ✅ Kompatibel (kann zu Apache 2.0 kombiniert werden)  
- **GPL** → ❌ Nicht kompatibel mit Apache 2.0 (außer双重 Lizenz)  
- **SNOMED International** → 🟡 Einschränkungen (Verbreitung, Embedding)

---

### 3.3 Lizenz-Hinweise in DIZ

- ✅ **Doku führen:** Welche Lizenzen wurden heruntergeladen? (Audit!)  
- ✅ **Hinweise geben:** Im DIZ-Handbuch: Benutzungsbedingungen (z. B. „Nicht weiterverbreiten“)  
- ✅ **Lizenz-Updates:** Monatliche Prüfung (z. B. für ICD-10-GM Updates)

---

## 🚀 Zukunft: Weitere Inhalte

### 4.1 Ausblick: Themen für zukünftige Übungen

| Themenbereich | Inhalt | Relevanz |
|---------------|--------|----------|
| **Pseudonymisierung** | Anonymisierung von FHIR-Ressourcen (de-idenfikation, k-Anonymity) | ✅✅✅ Kritisch für Forschungsdaten |
| **Datenanalyse mit Skripten** | Externe Forschende liefern R-Skripte/Python-Skripte | ✅✅✅ Alltag in DIZ |
| **DIMP/DUP-Pipeline** | aether-orchestrierte Datenbereitstellung | ✅✅✅ Backend für Forschungsanfragen |
| ** consent-Management** | MII Consent-Validierung (DSTU2 vs. R4) | ✅✅✅ Rechtliche Compliance |
| **FHIR-Konformance** | CapabilityStatement, StructureDefinition-Validation | ✅✅ Technische Qualität |

---

### 4.2 Konkrete Ideen für weitere Übungen

#### **Exercise 8: Pseudonymisierung von FHIR-Daten**
 
- MII FHIR-Pseudonymizer

#### **Exercise 9: Analyse mit externen Skripten**

- R-Script / Python-Script von Forschendem bekommen  
- Ergebnis exportieren (CSV, JSON, FHIR-Bundle)

#### **Exercise 10: DIMP/DUP-Pipeline (Ausblick)**

- Welche Daten werden in die Pipeline eingespeist?  
- Wie wird eine Forschungsanfrage bearbeitet? (DIMP → DUP → Export)  
- Aether-Orchestrierung (Kubernetes, ArgoCD)

---

## 🏁 Zusammenfassung

### Zusammenfassung: Womit du im DIZ-Arbeitsalltag arbeitest

| Werkzeug | Getestet | Lokal/remote? | Lizenz |
|----------|-----------|---------------|--------|
| **Blaze Server** | ✅ Ja | ✅ Lokal | Apache 2.0 |
| **MII SU-TermServ** | ✅ Ja | ✅ Beides | — |
| **MII FHIR Validator** | ✅ Ja | ✅ Lokal | Apache 2.0 |
| **LOINC** | ✅ Ja | ✅ Kostenlos | Apache 2.0 |
| **ICD-10-GM/OPS** | ✅ Ja | ✅ Kostenlos | public domain |
| **SNOMED-CT** | ✅ Ja | ❌ kostenpflichtig | SNOMED International |

___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • **Exercise 7**
___
___