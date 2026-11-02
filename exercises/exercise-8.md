___
___
[Prerequisites](prerequisites.md) • [Dienste](services.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md) • **Exercise 8**
___
___

# ⚫ Ausblick: Sonstiges

**Nächste Schritte:**

- Lerne Alternativen zu den Werkzeugen aus den Übungen kennen
- Verstehe, warum Versionen von Codesystemen und Profilen wichtig sind
- Verschaffe dir einen Überblick über die Lizenzen der Codesysteme

In den vorherigen Übungen hast du **FHIR-Profile definiert**, **Daten in einen FHIR-Server geladen**, **Abfragen gestellt**, **Terminologien geladen** und **Ressourcen validiert**.

In dieser letzten Übung schauen wir auf **alternative Werkzeuge**, **Versionierung** und **Lizenzen** – ohne praktische Übung, aber mit dem nötigen Kontext, um im DIZ-Alltag informierte Entscheidungen zu treffen.

___

📋 **Übersicht:**

- [Alternative Werkzeuge](#alternativen)
- [Versionierung von Codesystemen und Profilen](#versionierung)
- [Lizenzen](#lizenzen)
- [Ideen für weitere Themen](#weitere-themen)
- [Zusammenfassung](#zusammenfassung)

___

## <a id="alternativen"></a>🔧 Alternative Werkzeuge

### 1.1 Terminologieserver

| Server | Eigenschaften | Einsatz |
| ------ | ------------- | ------- |
| **FHIRsmith** ([Exercise 5](exercise-5.md)) | Open Source (BSD-3), Software hinter tx.fhir.org | Lokale Tests, Lernen, eigene Instanzen |
| **Ontoserver** (CSIRO) | Kommerziell, sehr ausgereift, SNOMED-CT-Unterstützung | Betrieben von der MII Service Unit Terminologie (SU-TermServ) |
| **Blaze** mit Terminologie-Modul | Open Source, derselbe Blaze wie aus [Exercise 2](exercise-2.md), kann LOINC und SNOMED CT laden | Standard-Terminologieserver im Setup des MII FHIR Validators |
| **HAPI FHIR** | Open Source, Terminologie-Funktionen als Teil des FHIR-Servers | Wenn HAPI ohnehin als FHIR-Server läuft |

___

### 1.2 Validatoren

| Werkzeug | Eigenschaften |
| -------- | ------------- |
| **MII FHIR Validator** ([Exercise 6](exercise-6.md)) | HL7-Validator als HTTP-Dienst, vorkonfiguriert mit den MII-KDS-Paketen |
| **HL7 Validator** (`validator_cli.jar`) | Referenz-Validator von HL7, Basis von MII FHIR Validator und IG Publisher; Kommandozeile, gut für CI |
| **Firely Terminal / Firely SDK** | Eigene Validator-Implementierung (.NET); Firely Terminal kennst du aus [Exercise 1](exercise-1.md) |
| **gematik Referenzvalidator** | Basiert auf dem HL7-Validator, vorkonfiguriert für Anwendungen der Telematikinfrastruktur (z. B. E-Rezept, ISiK) |
| **Simplifier.net** | Webplattform mit Validierung, Profil-Browser und Paket-Registry |

> 💡 Validatoren auf derselben Basis (HL7-Validator) liefern bei gleicher Konfiguration dieselben Ergebnisse. Unterschiede entstehen vor allem durch geladene Pakete, Versionen und den Terminologieserver.

___

### 1.3 FHIR-Server

| Server | Eigenschaften |
| ------ | ------------- |
| **Blaze** ([Exercise 2](exercise-2.md)) | Open Source (Apache 2.0), leichtgewichtig, in der MII weit verbreitet |
| **HAPI FHIR JPA Server** | Open Source, sehr verbreitet, viele Erweiterungen |
| **Firely Server** | Kommerziell (.NET) |
| **Cloud-Dienste** (AWS HealthLake, Azure Health Data Services, Google Cloud Healthcare API) | Gemanagt, aber Datenhaltung in der Cloud ist für Patientendaten im DIZ meist keine Option |

___

## <a id="versionierung"></a>🔢 Versionierung von Codesystemen und Profilen

### 2.1 Warum Versionierung?

| Szenario | Problem ohne Versionsangabe |
| -------- | -------------------------- |
| **ICD-10-GM-Update** | Die ICD-10-GM erscheint jährlich. Ein Code aus 2023 kann 2026 gestrichen oder umbenannt sein. Gegen welche Version prüft man? |
| **Neue Profilversion** | Die Musterdaten nennen Profile von 2024/2025, der Validator aus [Exercise 6](exercise-6.md) lädt 2026. Welche Regeln gelten? |
| **Nachvollziehbarkeit** | Welcher Code und welches Profil galten zum Zeitpunkt der Dokumentation? |

___

### 2.2 Versionen in FHIR angeben

Eine `Coding` kann die Version des Codesystems mitführen:

```json
{
  "code": {
    "coding": [
      {
        "system": "http://fhir.de/CodeSystem/bfarm/icd-10-gm",
        "version": "2026",
        "code": "I10.90",
        "display": "Essentielle Hypertonie, nicht näher bezeichnet: Ohne Angabe einer hypertensiven Krise"
      }
    ]
  }
}
```

Profile werden mit `|` und Version referenziert, z. B. in `meta.profile`:

```text
https://www.medizininformatik-initiative.de/fhir/core/modul-diagnose/StructureDefinition/Diagnose|2025.0.0
```

___

### 2.3 Praxis-Tipps

| Praxis-Problem | Lösung |
| -------------- | ------ |
| **Mehrere Codesystem-Versionen parallel** | `coding.version` befüllen; Terminologieserver mit allen benötigten Versionen bestücken |
| **Codes ändern sich zwischen Versionen** | Überleitungstabellen des BfArM für ICD-10-GM und OPS nutzen |
| **Daten mit älterer Profilversion** | Vor der Validierung festlegen, gegen welche Version geprüft wird, und die passenden Pakete laden |

___

## <a id="lizenzen"></a>📜 Lizenzen

### 3.1 Codesysteme

| Codesystem | Lizenz | Kosten | Bezug |
| ---------- | ------ | ------ | ----- |
| **ICD-10-GM, OPS, Alpha-ID-SE** | Downloadbedingungen des BfArM | Kostenfrei | [BfArM](https://www.bfarm.de/DE/Kodiersysteme/_node.html) |
| **LOINC** | Eigene LOINC-Lizenz (Regenstrief Institute) | Kostenfrei, Registrierung nötig | [loinc.org](https://loinc.org) |
| **SNOMED CT** | SNOMED-International-Affiliate-Lizenz | In Deutschland kostenfrei (nationale Lizenz), Lizenzvergabe über das BfArM | [BfArM](https://www.bfarm.de/DE/Kodiersysteme/Terminologien/SNOMED-CT/_node.html) |
| **UCUM** | Eigene Nutzungsbedingungen (Regenstrief Institute) | Kostenfrei | [ucum.org](https://ucum.org) |

> 💡 **SNOMED CT** ist seit 2021 in Deutschland national lizenziert. Nutzende brauchen trotzdem eine eigene (kostenfreie) Affiliate-Lizenz über das BfArM, bevor sie die Release-Dateien herunterladen dürfen.

___

### 3.2 Software

Die Werkzeuge der Übungen stehen unter Open-Source-Lizenzen: Blaze, der MII FHIR Validator und der HL7-Validator unter Apache 2.0, FHIRsmith unter BSD-3. Diese Lizenzen regeln nur die **Software**. Die Inhalte, die du lädst (z. B. LOINC oder SNOMED CT), haben eigene Lizenzen, und die gelten auch dann, wenn die Software frei ist.

___

### 3.3 Lizenz-Hinweise im DIZ

- ✅ **Dokumentieren:** Welche Terminologien in welcher Version unter welcher Lizenz geladen wurden
- ✅ **Weitergabe prüfen:** Lizenzpflichtige Inhalte (z. B. SNOMED-CT-Releasedateien) nicht in Repositories oder Docker-Images einbauen
- ✅ **Releasezyklen im Blick behalten:** ICD-10-GM und OPS erscheinen jährlich, LOINC zweimal im Jahr

___

## <a id="weitere-themen"></a>🚀 Ideen für weitere Themen

| Themenbereich | Inhalt | Relevanz |
| ------------- | ------ | -------- |
| **Pseudonymisierung** | De-Identifikation von FHIR-Ressourcen, z. B. mit dem FHIR Pseudonymizer | ✅✅✅ Kritisch für Forschungsdaten |
| **Datenanalyse mit Skripten** | Externe Forschende liefern R- oder Python-Skripte, die im DIZ laufen | ✅✅✅ Alltag im DIZ |
| **Datenausleitung (TORCH, DIMP/DUP)** | Aether-orchestrierte Datenbereitstellung für Forschungsanfragen | ✅✅✅ Backend für Forschungsanfragen |
| **Consent** | MII-Consent-Profile, Prüfung der Einwilligung bei der Datenausleitung | ✅✅✅ Rechtliche Grundlage |
| **FHIR-Konformität** | `CapabilityStatement` lesen, Profile eines Servers prüfen | ✅✅ Technische Qualität |

___

## <a id="zusammenfassung"></a>🏁 Zusammenfassung

### Womit du in den Übungen gearbeitet hast

| Werkzeug / Inhalt | In Übung | Betrieb | Lizenz |
| ----------------- | -------- | ------- | ------ |
| **SUSHI, IG Publisher** | [Exercise 1](exercise-1.md) | Lokal | Apache 2.0 |
| **Blaze** | [Exercise 2](exercise-2.md)–[4](exercise-4.md) | Lokal (Docker) | Apache 2.0 |
| **FHIRsmith** | [Exercise 5](exercise-5.md) | Lokal (Docker) | BSD-3 |
| **ICD-10-GM, OPS, Alpha-ID-SE** | [Exercise 5](exercise-5.md) | Auf FHIRsmith geladen | BfArM, kostenfrei |
| **MII FHIR Validator** | [Exercise 6](exercise-6.md)–[7](exercise-7.md) | Lokal (Docker) | Apache 2.0 |
| **LOINC, SNOMED CT** | Nur als Codes in den Daten | Nicht geladen | Siehe [Lizenzen](#lizenzen) |

### Ausblick

Das Tutorial ist damit abgeschlossen. Du hast die wichtigsten Werkzeuge und Abläufe kennengelernt, mit denen ein DIZ FHIR-Daten modelliert, speichert, abfragt und prüft.

___
___
[Prerequisites](prerequisites.md) • [Dienste](services.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md) • **Exercise 8**
___
___
