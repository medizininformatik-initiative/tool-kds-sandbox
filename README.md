# tool-kds-sandbox

Eine praxisnahe Schulungsumgebung zum **MII-Kerndatensatz (KDS)** und zu **HL7 FHIR®**. Die Übungen entstehen im Aus-, Fort- und Weiterbildungsprojekt baseTrace und richten sich an **neue Mitarbeitende der Datenintegrationszentren (DIZe)**.

In acht aufeinander aufbauenden Übungen werden verschiedene Stationen auf dem Weg von Daten im MII-Kontext angeschnitten: von der Spezifikation eines FHIR-Profils über das Starten eines FHIR-Servers, die Kommunikation mit ihm sowie das Laden und Abfragen realitätsnaher Musterdaten bis hin zur Nutzung von Terminologiediensten, zur Validierung von FHIR-Ressourcen und zum Verstehen von Validierungsberichten.

> Alles läuft lokal auf deinem Rechner mit Open-Source-Werkzeugen.

___

## 📋 Übersicht

| | Übung | Was du tust | Werkzeuge | Umfang | Stand |
| :--- | :--- | :--- | :--- | :--- | :--- |
| ⚪ | [Prerequisites](exercises/prerequisites.md) | Dich orientieren & Entwicklungsumgebung vorbereiten | – | Checkliste | ✅ |
| 🔵 | [1 – FHIR-Profile definieren und Ressourcen generieren](exercises/exercise-1.md) | Profil und Beispielressource in FSH schreiben und kompilieren, Implementation Guide bauen | `sushi`, Firely Terminal, Java + IG Publisher | Groß · ca. 20 Befehlsblöcke, IG-Build ca. 10 min | ✅ |
| 🟢 | [2 – Einfaches Beispiel FHIR-Search](exercises/exercise-2.md) | Lokalen FHIR-Server starten, eigene Ressourcen hochladen und abfragen | Docker Compose, Blaze, `curl` | Klein · ca. 7 Befehlsblöcke | ✅ |
| 🟡 | [3 – KDS-Beispieldaten in FHIR-Server laden](exercises/exercise-3.md) | Musterdatenspende dreier Standorte aufbereiten, bereinigen und hochladen | `git`, `jq`, Bash-Skripte | Mittel · ca. 13 Befehlsblöcke | ✅ |
| 🟠 | [4 – Query von KDS-Daten](exercises/exercise-4.md) | Diagnosen, Laborwerte und Patienten in den UKSH-Musterdaten suchen, Ressourcen verknüpfen, Auffälligkeiten finden | `curl`, `jq`, optional fhir-pyrate / fhircrackr | Groß · ca. 20 Befehlsblöcke, 2 Aufgaben mit Lösung | 🚧 |
| 🔴 | [5 – Aufsetzen eines lokalen Terminologieservers](exercises/exercise-5.md) | Terminologieserver starten, deutsche Klassifikationen laden, Codes nachschlagen und prüfen | FHIRsmith, Docker Compose, `curl`, `jq` | Mittel · ca. 12 Befehlsblöcke, erster Start einige Minuten | 🚧 |
| 🟣 | [6 – Nutzen eines FHIR Validators](exercises/exercise-6.md) | Ressourcen, Profile und Musterdaten validieren | MII FHIR Validator, validator_cli | Mittel · ca. 6 Befehlsblöcke | 🚧 |
| 🟤 | [7 – Interpretieren von Ergebnissen](exercises/exercise-7.md) | Validierungsberichte lesen, filtern und typische Fehler beheben | `jq` | Mittel · ca. 5 Befehlsblöcke, viel Lesestoff | 🚧 |
| ⚫ | [8 – Ausblick: Sonstiges](exercises/exercise-8.md) | Alternativen, Versionierung von Codesystemen, Lizenzen | – | Klein · reine Theorie | 🚧 |

**Stand:** ✅ erprobt · 🚧 in Arbeit (Inhalte können sich noch ändern)

### Wie die Übungen aufeinander aufbauen

```text
 Ex 1  Profil & Ressource (FSH)
   ↓
 Ex 2  FHIR-Server (Blaze) starten, eigene Ressourcen hochladen
   ↓
 Ex 3  Echte Musterdaten in den Server laden
   ↓
 Ex 4  Musterdaten abfragen
   ↓
 Ex 5  Terminologieserver mit Codesystemen
   ↓
 Ex 6  Ressourcen gegen Profile und Terminologien validieren
   ↓
 Ex 7  Validierungsberichte interpretieren
   ↓
 Ex 8  Ausblick
```

Der in Exercise 2 gestartete FHIR-Server wird in den Übungen 3 und 4 weiterverwendet, die in Exercise 3 geladenen Daten sind die Grundlage für Exercise 4 und 6. Bearbeite die Übungen daher am besten in der angegebenen Reihenfolge.

___

## 🧩 Aufbau des Repositorys

| Bereich | Inhalt |
| :--- | :--- |
| `exercises/` | Die Übungsanleitungen. Jede Übung hat oben und unten eine Navigationsleiste zu allen anderen Übungen. |
| Musterlösungen | Fertige Lösungen (FSH-Projekt, Skripte) zu den Übungen – wo du sie findest, steht in den [Prerequisites](exercises/prerequisites.md#-hinweis-zu-den-übungsmaterialien--lösungen). |
| Musterdatenspende | Wird in Exercise 3 aus dem Repository [musterdatenspende-diz](https://github.com/medizininformatik-initiative/musterdatenspende-diz) geklont – nicht Teil dieses Repos. |

___

## ⚪ Prerequisites

Für die Übungen brauchst du:

- **Betriebssystem:** Linux oder Windows mit **WSL2**
- **Hardware:** mindestens **8 GB Arbeitsspeicher**
- **Rechte:** Sudo-Rechte zum Installieren von Paketen
- **Werkzeuge**, die im Laufe der Übungen eingerichtet werden:
  - Node.js mit `npm`, FSH-Compiler `sushi`, Firely Terminal (Exercise 1)
  - Java (ab 11, empfohlen 17 oder 21) und Jekyll für den IG Publisher (Exercise 1)
  - Docker und Docker Compose für FHIR-Server, Terminologieserver und Validator (ab Exercise 2)
  - `git`, `curl` und `jq` für Daten und Abfragen

👉 [Zur Checkliste](exercises/prerequisites.md)

___

## 🔵 Exercise 1 – [FHIR-Profile definieren und Ressourcen generieren](exercises/exercise-1.md)

> Voraussetzung: FSH-Compiler `sushi` per `npm` installiert.

- Eigenes SUSHI-Projekt anlegen und Ressourcen mit `sushi` bauen
- Anwendungsfall „ZuckerWatch-2026“ (Typ-2-Diabetes-Monitoring): ein Laborprofil auf Basis des KDS-Moduls Labor und eine Beispiel-Observation in FSH definieren
- FHIR-Packages verwalten (`~/.fhir`)
- Implementation Guide mit dem IG Publisher erzeugen und die Ressourcen im Browser ansehen

## 🟢 Exercise 2 – [Einfaches Beispiel FHIR-Search](exercises/exercise-2.md)

> Voraussetzung: Docker und Docker Compose installiert.

- Lokalen FHIR-Server **Blaze** per Docker Compose starten
- Patient und Observation aus Exercise 1 hochladen und den Unterschied zwischen `POST` (Server vergibt ID) und `PUT` (feste ID) kennenlernen
- Erste Suchanfragen per HTTP REST stellen (`code`, `subject`, `_count`)

## 🟡 Exercise 3 – [KDS-Beispieldaten in FHIR-Server laden](exercises/exercise-3.md)

> Voraussetzung: Blaze aus Exercise 2 läuft.

- Die **Musterdatenspende** der Standorte UKSH, UKHD und UKW klonen und in ein `transaction`-Bundle überführen
- Am ersten Upload-Versuch erleben, was **referenzielle Integrität** bedeutet
- Daten mit Skripten bereinigen und für den Upload vorbereiten (fehlerhafte Ressourcen entfernen, `POST` → `PUT`)
- Upload durchführen und das Ergebnis per Abfrage überprüfen

## 🟠 Exercise 4 – [Query von KDS-Daten](exercises/exercise-4.md)

> Voraussetzung: Musterdaten aus Exercise 3 sind im Server geladen.

- Pseudonymisierte Patienten erkunden, nach Geschlecht und Alter filtern, durch Ergebnisseiten blättern
- Diagnosen (ICD-10-GM) und Laborwerte (LOINC und lokale Codes) suchen, auffällige Werte wie eine Hyperkaliämie finden
- Ressourcen verknüpfen: Chaining, `_has`, `_include` (Befund mit Einzelwerten) und `_revinclude` (Patientenakte)
- Widersprüche und ungültige Codes in den Daten entdecken
- Ausblick auf skriptbasierte Auswertung mit Python (fhir-pyrate) und R (fhircrackr) sowie auf TORCH

## 🔴 Exercise 5 – [Aufsetzen eines lokalen Terminologieservers](exercises/exercise-5.md)

> Voraussetzung: Docker Compose aus Exercise 2, Musterdaten aus Exercise 3 (für den letzten Schritt).

- Überblick über Terminologien im DIZ (ICD-10-GM, OPS, LOINC, SNOMED CT, ATC, UCUM) und über Terminologieserver
- FHIRsmith per Docker Compose starten und ICD-10-GM, OPS und Alpha-ID-SE als FHIR-Pakete laden
- Codes mit `$lookup`, `$validate-code` und `$expand` nachschlagen, prüfen und suchen
- Diagnosecodes aus den Musterdaten in Blaze gegen den Terminologieserver prüfen

## 🟣 Exercise 6 – [Nutzen eines FHIR Validators](exercises/exercise-6.md)

> Voraussetzung: Terminologieserver aus Exercise 5.

- Strukturelle Validierung und Profil-Validierung unterscheiden, Werkzeuge vergleichen
- MII FHIR Validator per Docker starten
- Einzelne Ressourcen, Ressourcen gegen ein Profil und die Musterdaten aus Exercise 3 validieren
- Validierung über die Kommandozeile (validator_cli)

## 🟤 Exercise 7 – [Interpretieren von Ergebnissen](exercises/exercise-7.md)

> Voraussetzung: Validierungsbericht aus Exercise 6.

- Aufbau eines Validierungsberichts (`OperationOutcome`), Severity-Stufen und Issue-Typen
- Häufige Warnings und Errors mit Beispielen und Behebungstipps
- Berichte mit `jq` filtern und auswerten

## ⚫ Exercise 8 – [Ausblick: Sonstiges](exercises/exercise-8.md)

- Alternative Terminologieserver, Validatoren und FHIR-Server
- Versionierung von Codesystemen
- Lizenzen von Codesystemen im DIZ-Kontext
- Ideen für weitere Übungen

___

## 📄 Lizenz

Diese Dokumentation und die dazugehörigen Übungsunterlagen stehen unter der Lizenz **Creative Commons Attribution 4.0 International (CC BY 4.0)**.

Den vollständigen Lizenztext findest du im [Repository](LICENSE.txt) oder online: [https://creativecommons.org/licenses/by/4.0/deed.de](https://creativecommons.org/licenses/by/4.0/deed.de)

___

### Kontakt

- Jendrik Richter (UMG)
- baseTrace-Team
