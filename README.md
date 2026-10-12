# tool-kds-sandbox

Hier entsteht eine MII Kerndatensatz-Schulungsumgebung. Initiale Übungen werden aus dem Aus-, Fort- und Weiterbildungsprojekt baseTrace heraus erstellt. Die Schulungsumgebung soll Mitte 2026 mit einem initialen Satz an Übungen/Inhalten verfügbar werden. Zukünftig können weitere Übungen/Inhalte entwickelt und hinzugefügt werden.

- Zielgruppe:
  - Neue Mitarbeitende der DIZe
- Zukünftige Themen:
  - Implementierung von KDS-Profilen
  - Verarbeiten von FHIR-Beispieldaten
  - Validierung von Ressourcen und Profilen

## ⚪ ⚪ Prerequisites -> [Link in den Übungsbereich](exercises/prerequisites.md)

Um die nachfolgenden Übungen lösen zu können, bedarf es einer Entwicklungsumgebung mit verschiedenen technischen Werkzeugen sowie eines Textbearbeitungsprogramm und minimal 8GB Arbeitsspeicher. Die wichtigsten Werkzeuge (Referenzauswahl) sind im Folgenden aufgelistet:

- FHIR-Shorthand (FSH) - Compiler `sushi`
- Versionsverwaltung `git`
- Container Service `Docker-Compose`
- FHIR Store / Server `blaze`
- Terminologie-Server `blaze` (TermServ)
- Validierungsservice `MII FHIR Validator`

## 🔵 🔵 Exercise 1 - [FHIR-Profilen definieren und Ressourcen generieren](exercises/exercise-1.md)

> \> FSH-Compiler `sushi` eingerichtet. (NPM-Installation)

- Ressourcen mittels `sushi` builden
  - Verwalten von FHIR-Packages (`~./fhir`)
- Beispielprofil und Beispielressource in `fsh` definieren
- Anwendungsfallbeispiel mit KDS-Bezug
- IG generieren und Ressourcen visualisieren

## 🟢 🟢 Exercise 2 - [Einfaches Beispiel FHIR-Search](exercises/exercise-2.md)

> \> (Lokalen) FHIR Store/Server gestartet. (Docker-Compose)

- Beispielressource in den FHIR Server hochladen
- Beispielabfragen via HTTP REST

## 🟡 🟡 Exercise 3 - [Beispiel-Daten in FHIR-Server laden](exercises/exercise-3.md)

> \> (Lokalen) FHIR Store/Server gestartet. (Docker-Compose)

- Builden von Beispieldaten:
  - `MII Musterdaten` oder `MII KDS Testdaten`
  - Verwalten von FHIR-Packages (`~./fhir`)
- Beispieldaten in den FHIR Server hochladen

## 🟠 🟠 Exercise 4 - [Query von KDS-Daten](exercises/exercise-4.md)

> \> (Lokalen) FHIR Store/Server gestartet. (Docker-Compose)

- Abfragen auf Beispielprofil bzw. Ressourcen
- Abfragen auf KDS-Profilen
- Ausblick auf TORCH?

## 🔴 🔴 Exercise 5 - [Aufsetzen eines lokalen Terminologieservers](exercises/exercise-5.md)

> \> Lokalen Terminologieserver gestartet. (Docker-Compose)

- Terminologien aus zentralen Quellen runterladen
  - [https://terminologien.bfarm.de](https://terminologien.bfarm.de) (ATC, ICD-10-GM, LOINC, OPS, UCUM, ...)
  - [https://www.nlm.nih.gov/healthit/snomedct/](https://www.nlm.nih.gov/healthit/snomedct/) (SNOMED-CT)
- Terminologie-Packete in lokalen TermServ hochladen
  - ICD-10-GM
  - SNOMED-CT
  - LOINC

## 🟣 🟣 Exercise 6 - [Nutzen des MII FHIR Validators](exercises/exercise-6.md)

> \> MII FHIR Validator lokal eingerichtet und gestartet. (Docker-Compose)

- Validator-Umgebungsvariablen konfigurieren?
- Einzelne Profile validieren
- Einzelne Ressourcen validieren
- Beispieldaten validieren

## 🟤 🟤 Exercise 7 - [Interpretieren von Ergebnissen](exercises/exercise-7.md)

> \> Validierungsreport erzeugt.

- Validierungsreport auswerten
- Häufige Warnings
- Häufige Errors

## ⚫ ⚫ Exercise 8 - [Ausblick: Sonstiges](exercises/exercise-8.md)

- Alternative Terminologieserver
- Alternative Validierungsservices
- Versionierung von Codesystemen
- Lizenzen
- ...

## Ende

___

### Kontakt

- Jendrik Richter (UMG)
- baseTrace-Team
