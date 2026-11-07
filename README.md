# tool-kds-sandbox

Eine praxisnahe Schulungsumgebung zum **MII-Kerndatensatz (KDS)** und zu **HL7 FHIR®**. Die Übungen entstehen im Aus-, Fort- und Weiterbildungsprojekt baseTrace und richten sich an **neue Mitarbeitende der Datenintegrationszentren (DIZe)**.

In sieben aufeinander aufbauenden Übungen werden verschiedene Stationen auf dem Weg von Daten im MII-Kontext angeschnitten: von der Spezifikation eines FHIR-Profils über das Starten eines FHIR-Servers, die Kommunikation mit ihm sowie das Laden und Abfragen realitätsnaher Musterdaten bis hin zur Nutzung von Terminologiediensten, zur Validierung von FHIR-Ressourcen und zum Verstehen von Validierungsberichten.

> Alles läuft lokal auf deinem Rechner mit Open-Source-Werkzeugen. Nur in [Übung 5 · Codes prüfen](exercises/exercise-5.md) nutzt du zusätzlich den öffentlichen Terminologieserver tx.fhir.org und in [Übung 6 · Ressourcen validieren](exercises/exercise-6.md) – optional, mit Client-Zertifikat – den MII Ontoserver.

___

## 📋 Übersicht

| | Übung | Was du tust | Werkzeuge | Umfang | Stand |
| :--- | :--- | :--- | :--- | :--- | :--- |
| ⚪ | [Voraussetzungen](exercises/prerequisites.md) | Dich orientieren & Entwicklungsumgebung vorbereiten | – | Checkliste | ✅ |
| 🔵 | [1 · Profil erstellen](exercises/exercise-1.md) | Profil und Beispielressource in FSH schreiben und kompilieren, Implementation Guide bauen | `sushi`, Firely Terminal, Java + IG Publisher | Groß · ca. 20 Befehlsblöcke, IG-Build ca. 10 min | ✅ |
| 🟢 | [2 · FHIR-Server starten](exercises/exercise-2.md) | Lokalen FHIR-Server starten, eigene Ressourcen hochladen und abfragen | Docker Compose, Blaze, `curl` | Klein · ca. 8 Befehlsblöcke | ✅ |
| 🟡 | [3 · Musterdaten laden](exercises/exercise-3.md) | Musterdatenspende dreier Standorte aufbereiten, bereinigen und hochladen | `git`, `jq`, Bash-Skripte | Mittel · ca. 18 Befehlsblöcke | ✅ |
| 🟠 | [4 · Daten abfragen](exercises/exercise-4.md) | Diagnosen, Laborwerte und Patienten in den Musterdaten suchen, Ressourcen verknüpfen, Auffälligkeiten finden | `curl`, `jq`, optional fhir-pyrate / fhircrackr | Groß · ca. 30 Befehlsblöcke | ✅ |
| 🔴 | [5 · Codes prüfen](exercises/exercise-5.md) | Codesysteme in den Musterdaten finden, Codes am öffentlichen Terminologieserver nachschlagen und prüfen, Grenzen erkennen | tx.fhir.org, `curl`, `jq` | Mittel · ca. 18 Befehlsblöcke | ✅ |
| 🟣 | [6 · Ressourcen validieren](exercises/exercise-6.md) | Validator mit eigenem Terminologieserver starten, eigene Ressource und Musterdaten gegen KDS-Profile validieren | FHIRsmith, MII FHIR Validator, Docker Compose, `curl`, `jq` | Groß · ca. 24 Befehlsblöcke, erster Start Terminologieserver ca. 15 min, Validator ca. 5 min | ✅ |
| 🟤 | [7 · Berichte auswerten](exercises/exercise-7.md) | Validierungsberichte lesen, filtern und Meldungen einordnen | `jq`, Bash-Skript | Mittel · ca. 9 Befehlsblöcke | ✅ |

**Stand:** ✅ erprobt · 🚧 in Arbeit (Inhalte können sich noch ändern)

### Wie die Übungen aufeinander aufbauen

```text
 1 · Profil erstellen        FSH-Profil und Beispielressource schreiben
   ↓
 2 · FHIR-Server starten     Blaze starten, eigene Ressourcen hochladen
   ↓
 3 · Musterdaten laden       Musterdatenspende aufbereiten und hochladen
   ↓
 4 · Daten abfragen          Musterdaten mit FHIR-Search abfragen
   ↓
 5 · Codes prüfen            Codes an tx.fhir.org nachschlagen und prüfen
   ↓
 6 · Ressourcen validieren   Terminologieserver einrichten, gegen KDS-Profile validieren
   ↓
 7 · Berichte auswerten      Validierungsberichte lesen und einordnen
```

Der in [Übung 2 · FHIR-Server starten](exercises/exercise-2.md) gestartete FHIR-Server wird in den Übungen 3 und 4 weiterverwendet, die in [Übung 3 · Musterdaten laden](exercises/exercise-3.md) geladenen Daten sind die Grundlage für die Übungen 4 bis 7. Bearbeite die Übungen daher am besten in der angegebenen Reihenfolge.

___

## 🧩 Aufbau des Repositorys

| Bereich | Inhalt |
| :--- | :--- |
| `exercises/` | Die Übungsanleitungen. Jede Übung hat oben und unten eine Navigationsleiste zu allen anderen Übungen, zu den Voraussetzungen und zur Seite [Dienste](exercises/services.md). |
| Musterlösungen | Fertige Lösungen (FSH-Projekt, Skripte) zu den Übungen – wo du sie findest, steht in den [Voraussetzungen](exercises/prerequisites.md#-hinweis-zu-den-übungsmaterialien--lösungen). |
| Musterdatenspende | Wird in [Übung 3 · Musterdaten laden](exercises/exercise-3.md) aus dem Repository [musterdatenspende-diz](https://github.com/medizininformatik-initiative/musterdatenspende-diz) geklont – nicht Teil dieses Repos. |

___

## ⚪ Voraussetzungen

Für die Übungen brauchst du:

- **Betriebssystem:** Linux oder Windows mit **WSL2**
- **Hardware:** mindestens **8 GB**, empfohlen **16 GB Arbeitsspeicher**
- **Rechte:** Sudo-Rechte zum Installieren von Paketen
- **Werkzeuge**, die im Laufe der Übungen eingerichtet werden:
  - Node.js mit `npm`, FSH-Compiler `sushi`, Firely Terminal ([Übung 1 · Profil erstellen](exercises/exercise-1.md))
  - Java (ab 11, empfohlen 17 oder 21) und Jekyll für den IG Publisher ([Übung 1 · Profil erstellen](exercises/exercise-1.md))
  - Docker und Docker Compose für FHIR-Server, Terminologieserver und Validator (ab [Übung 2 · FHIR-Server starten](exercises/exercise-2.md))
  - `git`, `curl`, `jq` und `unzip` für Daten und Abfragen
- **Dienste:** Blaze (`8080`), FHIRsmith (`8081`) und MII FHIR Validator (`8082`) als Docker-Container – gesammelt auf der Seite [Dienste](exercises/services.md)

👉 [Zur Checkliste](exercises/prerequisites.md)

___

## 🔵 [1 · Profil erstellen](exercises/exercise-1.md)

> Voraussetzung: FSH-Compiler `sushi` per `npm` installiert.

- Eigenes SUSHI-Projekt anlegen und Ressourcen mit `sushi` bauen
- Anwendungsfall „ZuckerWatch-2026“ (Typ-2-Diabetes-Monitoring): ein Laborprofil auf Basis des KDS-Moduls Labor und eine Beispiel-Observation in FSH definieren
- FHIR-Packages verwalten (`~/.fhir`)
- Implementation Guide mit dem IG Publisher erzeugen und die Ressourcen im Browser ansehen

## 🟢 [2 · FHIR-Server starten](exercises/exercise-2.md)

> Voraussetzung: Docker und Docker Compose installiert.

- Lokalen FHIR-Server **Blaze** per Docker Compose starten
- Patient und Observation aus [Übung 1 · Profil erstellen](exercises/exercise-1.md) hochladen und den Unterschied zwischen `POST` (Server vergibt ID) und `PUT` (feste ID) kennenlernen
- Erste Suchanfragen per HTTP REST stellen (`code`, `subject`, `_count`)

## 🟡 [3 · Musterdaten laden](exercises/exercise-3.md)

> Voraussetzung: Blaze aus [Übung 2 · FHIR-Server starten](exercises/exercise-2.md) läuft.

- Die **Musterdatenspende** der Standorte UKSH, UKHD und UKW klonen und in ein `transaction`-Bundle überführen
- Am ersten Upload-Versuch erleben, was **referenzielle Integrität** bedeutet
- Daten mit Skripten bereinigen und für den Upload vorbereiten (fehlerhafte Ressourcen entfernen, `POST` → `PUT`)
- Upload durchführen und das Ergebnis per Abfrage überprüfen

## 🟠 [4 · Daten abfragen](exercises/exercise-4.md)

> Voraussetzung: Musterdaten aus [Übung 3 · Musterdaten laden](exercises/exercise-3.md) sind im Server geladen.

- Vorgehen wie bei unbekannten Daten: erst Überblick, dann auffällige Stelle und betroffene Ressourcen finden, dann nachsehen
- Patienten der drei Standorte erkunden, nach Geschlecht und Alter filtern, durch Ergebnisseiten blättern
- Diagnosen (ICD-10-GM) und Laborwerte (LOINC und lokale Codes) suchen, auffällige Werte wie hohe Kaliumwerte im Verlauf und im Befund einordnen
- Ressourcen verknüpfen: Chaining, `_has`, `_include` (Befund mit Einzelwerten) und `_revinclude` (Patientenakte)
- Widersprüche und ungültige Codes in den Daten entdecken
- Ausblick auf skriptbasierte Auswertung mit Python (fhir-pyrate) und R (fhircrackr) sowie auf TORCH

## 🔴 [5 · Codes prüfen](exercises/exercise-5.md)

> Voraussetzung: Blaze mit Musterdaten aus [Übung 3 · Musterdaten laden](exercises/exercise-3.md), Internetzugang.

- Überblick über Terminologien im DIZ (ICD-10-GM, OPS, LOINC, SNOMED CT, ATC, UCUM) und über Terminologieserver
- Herausfinden, welche Codesysteme in den Musterdaten stecken
- Codes mit `$lookup`, `$validate-code` und `$expand` am öffentlichen Terminologieserver tx.fhir.org nachschlagen, prüfen und suchen
- Codes aus Blaze automatisch prüfen und erkennen, was ein internationaler Terminologieserver nicht kennt (ICD-10-GM, OPS, MII-Codesysteme)

## 🟣 [6 · Ressourcen validieren](exercises/exercise-6.md)

> Voraussetzung: Blaze mit Musterdaten ([Übung 3 · Musterdaten laden](exercises/exercise-3.md)), Grundlagen der Terminologie-Operationen ([Übung 5 · Codes prüfen](exercises/exercise-5.md)).

- Strukturelle Validierung und Profil-Validierung unterscheiden, Validatoren im MII-Kontext einordnen
- Eigenen Terminologieserver mit deutschen Klassifikationen starten (FHIRsmith: ICD-10-GM, OPS, Alpha-ID-SE) und – mit Client-Zertifikat – den zentralen MII Ontoserver ausprobieren
- MII FHIR Validator per Docker Compose starten und mit diesem Terminologieserver verbinden
- Eigene HbA1c-Observation gegen das MII-Laborprofil und einzelne Musterdaten aus Blaze validieren
- Erkennen, wann der Validator ein Profil gar nicht prüft (unbekannte Profilversion), die Prüfung gegen ein Profil erzwingen und so versteckte Datenfehler in den Musterdaten finden
- Ausblick: Validierung über die Kommandozeile (`validator_cli.jar`)

## 🟤 [7 · Berichte auswerten](exercises/exercise-7.md)

> Voraussetzung: Validierungsbericht aus [Übung 6 · Ressourcen validieren](exercises/exercise-6.md).

- Aufbau eines Validierungsberichts (`OperationOutcome`), Severity-Stufen und Issue-Typen
- Häufige Validator-Meldungen und was zu tun ist
- Berichte mit `jq` filtern, zählen und Meldungen einordnen (Datenfehler, Versionsthema, Grenze des Setups), Versionen von Codesystemen und Profilen verstehen
- Was ein Validator nicht findet, am Beispiel des HbA1c-Profils aus [Übung 1 · Profil erstellen](exercises/exercise-1.md)

___

## 📄 Lizenz

Diese Dokumentation und die dazugehörigen Übungsunterlagen stehen unter der Lizenz **Creative Commons Attribution 4.0 International (CC BY 4.0)**.

Den vollständigen Lizenztext findest du im [Repository](LICENSE.txt) oder online: [https://creativecommons.org/licenses/by/4.0/deed.de](https://creativecommons.org/licenses/by/4.0/deed.de)

___

### Kontakt

- Jendrik Richter (UMG)
- baseTrace-Team
