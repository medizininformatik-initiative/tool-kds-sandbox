# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projekt

MII-Kerndatensatz-(KDS-)Schulungsumgebung für neue Mitarbeitende der DIZe (Projekt baseTrace). Das Repo ist primär **deutschsprachiger Markdown-Lehrinhalt** plus Bash-/FSH-Musterlösungen – es gibt keinen Build, keine Tests und keinen Linter im Repo.

Ausführlicher Projektstatus, Backlog und Stilregeln stehen in [agentic.md](agentic.md) – vor größeren Änderungen lesen und bei Statusänderungen mitpflegen.

## Struktur

- `exercises/prerequisites.md`, `exercises/exercise-1.md` … `exercise-8.md` – die Übungen; jede baut auf der vorherigen auf (FSH/SUSHI → Blaze-Upload → Musterdaten laden → Query → Terminologieserver → Validator → Ergebnisse interpretieren → Ausblick).
- `solution-exercise-N/` – Musterlösung zur jeweiligen Übung (auf `develop` als Ordner). Die Übungstexte beschreiben den Zielzustand auf `main`, wo die Lösungen in Solution-Branches (`solution_exercise-N`) liegen sollen. Diese Hinweise nicht an den develop-Stand anpassen.
- `README.md` – Kurzübersicht aller Übungen; Überschriften/Farbemojis müssen zu den Übungstiteln passen.
- `local_notes/` – per `.gitignore` ausgeschlossen, nicht committen.

## Gemeinsamer Kontext der Übungen

- Laufzeitumgebung der Lernenden: Linux oder WSL2, Werkzeuge `sushi` (npm `fsh-sushi`), Java + IG Publisher, `docker compose`, `curl`, `jq`. Keine weiteren Abhängigkeiten einführen.
- FHIR-Server ist **Blaze** (`samply/blaze`, `http://localhost:8080/fhir`, gestartet per `docker compose up -d` aus Exercise 2). Blaze erzwingt referenzielle Integrität und lässt sich nicht abschalten – das prägt Exercise 3.
- Datenquelle ist die **Musterdatenspende** (`medizininformatik-initiative/musterdatenspende-diz`) mit drei Standorten (UKSH, UKW, UKHD), nicht die MII-Testdaten.

### Exercise-3-Pipeline (`solution-exercise-3/`)

Die drei Skripte bilden eine Kette; Ausgabedateinamen werden jeweils an den Eingabenamen angehängt:

1. `clean_bundle.sh <bundle>.json` → `<bundle>_cleaned.json` – entfernt iterativ Ressourcen mit nicht auflösbaren Referenzen (bewusst „Remove“ statt „Repair“, siehe `solution-exercise-3/README.md`).
2. `prepare_upload.sh <x>.json` → `<x>_prepared.json` – nur für `searchset`-Bundles (UKW): konvertiert zu **`transaction`** (nicht `batch`, wegen zirkulärer Condition↔Encounter-Referenzen) und benennt doppelte IDs um.
3. `convert_to_put.sh <x>.json` → `<x>_put.json` – POST → PUT mit `resourceType/id`, damit IDs erhalten bleiben.

Upload: `curl -X POST http://localhost:8080/fhir -H "Content-Type: application/fhir+json" --data @<datei>_put.json`. UKSH und UKHD werden vorher mit `bin/merge-bundles.sh` aus dem Musterdatenspende-Repo zu einem Transaction-Bundle zusammengeführt.

## Nützliche Befehle

```bash
bash -n solution-exercise-3/*.sh                   # Syntaxcheck der Skripte
cd solution-exercise-1/ExampleIG && sushi .        # FSH → FHIR-Ressourcen
cd solution-exercise-1/ExampleIG && ./_build.sh    # IG Publisher (lädt publisher.jar nach)
```

`solution-exercise-1/` und `solution-exercise-2/` enthalten dasselbe `ExampleIG/`-Projekt – Änderungen an beiden Stellen nachziehen.

## Konventionen für Übungsdateien

- Kopf und Fuß jeder Übung: zwei `___`-Zeilen, Breadcrumb, zwei `___`-Zeilen. Breadcrumb verlinkt alle Seiten mit ` • ` als Trenner, die aktuelle Seite **fett ohne Link**, z. B.:
  `[Prerequisites](prerequisites.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • **Exercise 3** • [Exercise 4](exercise-4.md) • …`
  Kopf- und Fuß-Breadcrumb müssen identisch sein.
- Jede Übung hat ein festes Farbemoji im H1 (und in `README.md`): ⚪ Prerequisites, 🔵 1, 🟢 2, 🟡 3, 🟠 4, 🔴 5, 🟣 6, 🟤 7, ⚫ 8.
- Abschnittsüberschriften tragen Emojis aus der Palette in `prerequisites.md` (💡 ⚠️ ❗ 🔍 🏁 🛠️ 🧩 📋 📖 💻 ✅ …); neue Emojis nur nach Absprache.
- Codeblöcke: `bash` für Befehle (nicht `shell`), `json`, `text` für Ausgaben.
- Lösungsskripte gehören nach `solution-exercise-N/`, nicht in die Übungsdatei eingebettet; Pfade in Übungen relativ zu `~/tool-kds-sandbox` bzw. `~/musterdatenspende-diz` formulieren, keine nutzerspezifischen Absolutpfade.

## Git

- Arbeit auf `develop`; `main` nur für Releases – nie direkt auf `main` committen oder pushen.
- Bestehende Übungsinhalte nur ändern, wenn explizit gewünscht; ansonsten ergänzen.
