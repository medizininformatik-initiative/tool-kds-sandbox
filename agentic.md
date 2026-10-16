# agentic.md – Projekt-Kontext für KI-Agenten

> Dieses Dokument beschreibt den Projektstatus, Architekturentscheidungen und
> Konventionen, damit ein Agent in einer neuen Session ohne Vorkenntnisse
> produktiv weiterarbeiten kann. Allgemeine Repo-Hinweise stehen in `CLAUDE.md`.
>
> **Stand:** 2026-10-16

---

## 1. Repository & Branch

| Feld | Wert |
| --- | --- |
| **Repository** | `github.com/medizininformatik-initiative/tool-kds-sandbox` |
| **Branch** | `develop` (**niemals `main`** – main ist nur für Releases) |
| **Letzter Commit (develop)** | `8f54a4d` – Working upload for all three muster data sets |
| **Lokaler Clone (Windows)** | `C:\Users\M3nthos\Desktop\git-projects\tool-kds-sandbox` |
| **Musterdatenspende (lokal)** | `C:\Users\M3nthos\Desktop\git-projects\musterdatenspende-diz` (Geschwister-Ordner) |
| **Pfade in den Übungen** | `~/tool-kds-sandbox`, `~/musterdatenspende-diz` (Linux/WSL2 der Lernenden) |
| **Parallel-Repo** | `mii-kds-sandbox_setup-repo` (DevContainer/Codespace-Setup, wird später integriert) |

**develop vs. main:** Entwickelt wird auf `develop`, dort liegen die Musterlösungen als Ordner `solution-exercise-N/`. Die Texte (z. B. `prerequisites.md`: Lösungen in Solution-Branches `solution_exercise-N`) beschreiben bereits den **Zielzustand nach dem Merge nach `main`**. Diese Stellen also nicht an den develop-Stand „korrigieren“.

**Vor jeder Session:**

```bash
git checkout develop && git pull
```

💡 Unter Windows ist `jq` nicht installiert – die Skripte aus `solution-exercise-3/` laufen dort nicht direkt (WSL oder Python-Nachbau zum Prüfen nutzen).

---

## 2. Projektstatus

### Übungen (exercises/)

| Übung | Status | Datei | Bemerkung |
| --- | --- | --- | --- |
| ✅ Prerequisites | **Fertig** | `exercises/prerequisites.md` | Enthält Emoji-Referenz (wichtig für Stil) |
| ✅ Exercise 1 | **Fertig** | `exercises/exercise-1.md` | FSH-Profile + SUSHI + IG-Publishing |
| ✅ Exercise 2 | **Fertig** | `exercises/exercise-2.md` | Blaze starten, Ressourcen uploaden, FHIR Search |
| 🟡 Exercise 3 | **Funktional fertig** | `exercises/exercise-3.md` | Upload aller drei Standorte (UKSH, UKW, UKHD) funktioniert. Offen: Umstrukturierung & Präsentation |
| 📝 Exercise 4 | **Entwurf** | `exercises/exercise-4.md` | Query von KDS-Daten – Entwurf aus Commit `0febdc2`, ungetestet – **nächster Schritt** |
| 🟡 Exercise 5 | **Überarbeitet, Test läuft** | `exercises/exercise-5.md` | Auf FHIRsmith umgestellt (2026-10-16), Test auf GWDG-Server ausstehend |
| 📝 Exercise 6 | **Entwurf** | `exercises/exercise-6.md` | MII FHIR Validator, ungetestet |
| 📝 Exercise 7 | **Entwurf** | `exercises/exercise-7.md` | Ergebnisse interpretieren, ungetestet |
| 📝 Exercise 8 | **Entwurf** | `exercises/exercise-8.md` | Ausblick, Lizenzen, Alternativen |

### Lösungs-Ordner (solution-exercise-N/)

| Ordner | Status | Inhalt |
| --- | --- | --- |
| `solution-exercise-1/` | ✅ | `ExampleIG/` – komplettes SUSHI-Projekt (FSH-Dateien, sushi-config.yaml) |
| `solution-exercise-2/` | ✅ | Gleiches `ExampleIG/` (für Upload-Übung) – Änderungen in beiden Ordnern nachziehen |
| `solution-exercise-3/` | ✅ | `clean_bundle.sh`, `prepare_upload.sh`, `convert_to_put.sh` + `README.md` |
| `solution-exercise-4/` bis `-8/` | ❌ | Nur `.gitkeep` (Exercise 5 braucht keine Lösungsdateien, alle Konfigurationen stehen im Übungstext) |

### Exercise 3 – Ergebnisse (verifiziert)

| Standort | Rohdaten | Vorbereitung | Original | Nach Bereinigung | Entfernt |
| --- | --- | --- | --- | --- | --- |
| UKSH | Zip, 272 `searchset`-Dateien | `merge-bundles.sh` → transaction | 8.451 | 8.088 | 363 |
| UKW | 1 `searchset`-Datei | `prepare_upload.sh` → transaction | 235 | 234 | 1 |
| UKHD | Zip, 4 `searchset`-Dateien | `merge-bundles.sh` → transaction | 1.384 | 836 | 548 |

Zahlen am 2026-10-15 per Python-Nachbau von `clean_bundle.sh` gegen den lokalen Musterdatenspende-Clone ermittelt (ältere Angaben 8.446/8.083 waren falsch). Vor dem Merge nach `main` werden alle Übungen ohnehin komplett neu durchgetestet.

---

## 3. Architekturentscheidungen (wichtig für Konsistenz)

| Entscheidung | Begründung |
| --- | --- |
| **Datenquelle: Musterdatenspende (nicht MII-Testdaten)** | Enthält echte DIZ-Flavours (UKHD, UKSH, UKW), zeigt Heterogenität. Testdaten sind nur technisch/strukturell. |
| **Blaze als FHIR-Server (nicht HAPI)** | Leichtgewichtig, Docker, kein Java-Build nötig. Aber: referenzielle Integrität lässt sich nicht abschalten. |
| **„Remove“ statt „Repair“ (`clean_bundle.sh`)** | Ressourcen mit nicht auflösbaren Referenzen werden iterativ entfernt. Das frühere `repair-bundle.sh` (Dummy-Ressourcen erzeugen) wurde verworfen und gelöscht: zu komplex, Folgefehler (z. B. fehlende Patienten). |
| **PUT statt POST (`convert_to_put.sh`)** | `merge-bundles.sh` erzeugt POST → Blaze vergibt neue IDs, Referenzen brechen. PUT auf `resourceType/id` erhält die IDs. |
| **`transaction` statt `batch` (`prepare_upload.sh`)** | UKW enthält zirkuläre Referenzen (Condition ↔ Encounter); im `batch` scheitert die Integritätsprüfung pro Eintrag mit HTTP 409. |
| **Doppelte IDs umbenennen** | UKW enthält `Observation/LabResult-000000335` und `-346` doppelt → bei PUT Kollision. `prepare_upload.sh` hängt ein Suffix an. |
| **UKHD wie UKSH behandeln** | Alle 4 Dateien aus dem Zip werden per `merge-bundles.sh` zusammengeführt (nicht nur die größte Datei). |

Skriptkette und Dateinamen: Jedes Skript hängt ein Suffix an den Eingabenamen an (`_cleaned`, `_prepared`, `_put`). Beispiel UKW: `UKW-2025-12-05.json` → `_cleaned.json` → `_cleaned_prepared.json` → `_cleaned_prepared_put.json`.

---

## 4. Stil-Konventionen

### Markdown-Struktur jeder Übung

Jede Übungsdatei folgt diesem Schema:

```markdown
___                     # Trennlinie
___                     # Trennlinie
[Breadcrumb-Navigation]  # Siehe unten
___
___

# 🟡 TITEL (mit dem Farbemoji der Übung)

**Nächste Schritte:**   # Kurze Liste, was in der Übung passiert

Einleitender Text mit Bezug zu vorherigen Übungen.

___

## 💻 Schritt 1 (Setup-Schritte)
## 🛠️ Schritt 2 (praktische Übung)
## 📖 Schritt 3 (Theorie-Hintergrund)

...

## 🚀 Ausblick: Nächste Schritte   # Kurzer Ausblick auf die folgenden Übungen

___
___
[Breadcrumb-Navigation]  # Gleiche Leiste wie oben
___
___
```

### Farbemoji je Übung

Gilt für den H1-Titel der Übung und die Überschriften in `README.md`:

| Prerequisites | Ex 1 | Ex 2 | Ex 3 | Ex 4 | Ex 5 | Ex 6 | Ex 7 | Ex 8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ⚪ | 🔵 | 🟢 | 🟡 | 🟠 | 🔴 | 🟣 | 🟤 | ⚫ |

### Breadcrumb-Navigation

**Muss exakt so sein** – ` • ` als Trenner, aktuelle Seite **fett und ohne Link** (Beispiel Exercise 3):

```text
[Prerequisites](prerequisites.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • **Exercise 3** • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
```

Die Breadcrumb muss **sowohl in Zeile 3 als auch in der drittletzten Zeile** identisch stehen (aktuell bei allen Dateien erfüllt).

### Erlaubte Emojis (aus prerequisites.md)

| Emoji | Bedeutung | Einsatz |
| --- | --- | --- |
| 💡 | Tipp, Merksatz | Wichtige Hinweise |
| ⚠️ | Warnung | Stolperfallen |
| ❗ | Wichtiger Hinweis | Dringende Info |
| 🔍 | Detail / Genau hinschauen | Vertiefung |
| 🚀 | Start / Schnellkurs | Einstieg, Ausblick |
| 🏁 | Zielflagge | Ergebnis, Abschluss |
| 🛠️ | Vorbereitung/Setup | Praxisschritte |
| 🧩 | Modul / Zusammenhang | Struktur |
| 📋 | Navigation / Übersicht | Inhaltsverzeichnis |
| 📌 | Fixpunkt | Zusammenfassung |
| 📖 | Theorie | Hintergrundwissen |
| 💻 | Praxis-Schritte | Terminal-Befehle |
| ✅ | Richtig | Erfolgsmeldung |
| ❌ | Falsch | Negativbeispiele |

⚠️ Exercise 3–8 nutzen bereits weitere Emojis (z. B. 🚫 🧹 📤 🔄 📊 🎯 📥 📦 🔧 🔢 📜). Nicht weiter ausbauen; eine Bereinigung nur nach Absprache.

### Codeblöcke

- Bash-Befehle: ` ```bash ` (kein `shell`)
- JSON: ` ```json `
- FSH: ` ```fsh ` (alternativ ` ```bash `)
- Terminal-Ausgabe: ` ```text `
- Erwartete Ergebnisse als Kommentar (`# → ...`) oder separater Block

### Querverweise

- Auf andere Übungen: `[Exercise 2](exercise-2.md)`
- Auf externe URLs: Normale Markdown-Links
- Auf Abschnitte innerhalb der Datei: `[Schrittname](#abschnitt-id)`, bei Überschriften mit Emoji ggf. explizites Anker-Tag `<a id="..."></a>` (siehe Exercise 5–8)
- Pfade in Befehlen: `~/tool-kds-sandbox/...` und `~/musterdatenspende-diz/...`, keine nutzerspezifischen Absolutpfade

---

## 5. Ausführungshinweise für Agenten

### Arbeitsablauf

1. **Vorbereitung:** `git checkout develop` und `git pull`
2. **Änderungen umfassen immer:** Übungsdatei (`exercises/exercise-N.md`) + Lösungsdateien (`solution-exercise-N/`)
3. **Nach Fertigstellung:**
   - `bash -n` auf alle neuen `.sh`-Dateien
   - Prüfen, ob Breadcrumbs oben und unten identisch sind
   - Prüfen, ob alle internen Links funktionieren (existierende Dateien)
   - Dateinamen in Kommentaren (`# → erzeugt: ...`) gegen die tatsächliche Skriptausgabe prüfen
   - Debugger-Task mit Acceptance Criteria ausführen (Kriterien vorher festlegen)
   - `agentic.md` (Status, Backlog) aktualisieren
4. **Commit-Nachricht:** Kurz, beschreibend, z. B. `Vervollständigt Exercise 4 – Query von KDS-Daten`

### Verboten

- ❌ Niemals auf `main` committen oder pushen
- ❌ Niemals die bestehende Emoji-Palette erweitern (neue Emojis nur nach Absprache)
- ❌ Niemals bestehende Übungen inhaltlich verändern (nur ergänzen/reparieren, wenn explizit angewiesen)
- ❌ Keine neuen Abhängigkeiten einführen (immer mit Standard-Tools arbeiten: jq, curl, sushi, docker compose)
- ❌ `exercises/figures/` – keine Binärdateien ohne Absprache
- ❌ `local_notes/` ist per `.gitignore` ausgeschlossen – nichts daraus committen

---

## 6. Nächste Schritte (Backlog)

1. **Exercise 3 abschließen**
   - Umstrukturierung & Präsentation (laut Commit `8f54a4d` offen)
2. **Exercise 4 – Query von KDS-Daten** (Entwurf vorhanden, praktisch durchspielen)
   - Strukturierte Abfragen auf die in Ex 3 geladenen Musterdaten
   - Schwerpunkte: FHIR Search Parameter, Chaining, `_include`, `_revinclude`, `_filter`
   - Ausblick auf TORCH
   - Lösungen nach `solution-exercise-4/`
3. **Exercise 5** – Terminologieserver mit FHIRsmith (Port 8081, ICD-10-GM/OPS/Alpha-ID-SE aus MII-TermServ-GitLab): Ende-zu-Ende-Test, erwartete Ausgaben eintragen; HTTPS/nginx + fhir-settings.json für IG Publisher in Exercise 6 anleiten
4. **Exercise 6** – Mit dem MII FHIR Validator praktisch durchspielen
5. **Exercise 7** – Ergebnisse interpretieren
6. **Exercise 8** – Ausblick (Lizenzen, Alternativen)
7. **Beim Merge nach `main`:** Alle Übungen komplett neu durchtesten (Zahlen, Ausgaben, Dateinamen) und alles Nötige angleichen, damit Beschreibungen und Repo-Struktur übereinstimmen. Wird erst dann gemeinsam entschieden – vorher nichts vorwegnehmen.
8. **Allgemein:** Abschnitte „Nächste Schritte“ (Anfang) und „Ausblick“ (Ende) in jeder Übung vereinheitlichen; „Copy-Pasta“-Abschnitt in `prerequisites.md` später entfernen

---

## 7. Datenquellen (Referenzen)

| Ressource | URL |
| --- | --- |
| Musterdatenspende DIZ | `https://github.com/medizininformatik-initiative/musterdatenspende-diz` |
| MII-Testdaten | `https://github.com/medizininformatik-initiative/mii-testdata` |
| Blaze (FHIR Server) | `https://github.com/samply/blaze` / `samply/blaze:1.9.0` (in Exercise 2) |
| MII FHIR Validator | `https://github.com/medizininformatik-initiative/mii-fhir-validator` |
| KDS-Module (GitHub) | `https://github.com/orgs/medizininformatik-initiative/repositories?q=kerndatensatz` |
| FHIR Shorthand Docs | `https://hl7.org/fhir/uv/shorthand/overview.html` |
| SUSHI Docs | `https://fshschool.org/docs/SUSHI/` |
