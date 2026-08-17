# agentic.md – Projekt-Kontext für KI-Agenten

> Dieses Dokument beschreibt den Projektstatus, Architekturentscheidungen und
> Konventionen, damit ein Agent in einer neuen Session ohne Vorkenntnisse
> produktiv weiterarbeiten kann.

---

## 1. Repository & Branch

| Feld | Wert |
|---|---|
| **Repository** | `github.com/medizininformatik-initiative/tool-kds-sandbox` |
| **Branch** | `develop` (**niemals `main`** – main ist nur für Releases) |
| **Letzter Commit (develop)** | `4d41103` – Merge branch 'develop' of ... |
| **Lokaler Clone** | `/tmp/tool-kds-sandbox` |
| **Parallel-Repo** | `mii-kds-sandbox_setup-repo` (DevContainer/Codespace-Setup, wird später integriert) |

**Vor jeder Session:**
```bash
cd /tmp/tool-kds-sandbox
git checkout develop && git pull
```

---

## 2. Projektstatus

### Übungen (exercises/)

| Übung | Status | Datei | Bemerkung |
|---|---|---|---|
| ✅ Prerequisites | **Fertig** | `exercises/prerequisites.md` | Enthält Emoji-Referenz (wichtig für Stil) |
| ✅ Exercise 0 | **Fertig** | `exercises/exercise-0.md` | FSH-Profile + SUSHI + IG-Publishing |
| ✅ Exercise 1 | **Fertig** | `exercises/exercise-1.md` | Blaze starten, Ressourcen uploaden, FHIR Search |
| ✅ Exercise 2 | **Fertig** | `exercises/exercise-2.md` | **Zuletzt bearbeitet.** Musterdatenspende laden, repair-bundle.sh |
| ❌ Exercise 3 | **Leer** | `exercises/exercise-3.md` | Query von KDS-Daten – **nächster Schritt** |
| ❌ Exercise 4 | **Leer (nur Links)** | `exercises/exercise-4.md` | Terminologieserver aufsetzen |
| ❌ Exercise 5 | **Leer (nur Links)** | `exercises/exercise-5.md` | MII FHIR Validator nutzen |
| ❌ Exercise 6 | **Leer** | `exercises/exercise-6.md` | Ergebnisse interpretieren |
| ❌ Exercise 7 | **Leer** | `exercises/exercise-7.md` | Ausblick, Lizenzen, Alternativen |

### Lösungs-Ordner (tmp-solution_exercise-N/)

| Ordner | Status | Inhalt |
|---|---|---|
| `tmp-solution_exercise-0/` | ✅ | `ExampleIG/` – komplettes SUSHI-Projekt (FSH-Dateien, sushi-config.yaml) |
| `tmp-solution_exercise-1/` | ✅ | Gleiches `ExampleIG/` (für Upload-Übung) |
| `tmp-solution_exercise-2/` | ✅ | `repair-bundle.sh` + `README.md` |
| `tmp-solution_exercise-3/` bis `-7/` | ❌ | Nur `.gitkeep` |

---

## 3. Architekturentscheidungen (wichtig für Konsistenz)

| Entscheidung | Begründung |
|---|---|
| **Datenquelle: Musterdatenspende (nicht MII-Testdaten)** | Enthält echte DIZ-Flavours (UKHD, UKSH, UKW), zeigt Heterogenität. Testdaten sind nur technisch/strukturell. |
| **Blaze als FHIR-Server (nicht HAPI)** | Leichtgewichtig, Docker, kein Java-Build nötig. Aber: kein `enforceReferentialIntegrity=false`! |
| **repair-bundle.sh für referenzielle Integrität** | Da Blaze keine Option zum Deaktivieren hat, müssen broken references durch Dummy-Ressourcen ergänzt werden. |
| **Dummy-Ressourcen minimal halten** | Nur `id`, `resourceType` und zwingende Pflichtfelder (z. B. `status` bei Location/Encounter). |

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

# 🎨 TITEL (mit passendem Emoji)

Einleitender Text mit Bezug zu vorherigen Übungen.

📋 Übersicht:
- [Schritt 1](#)
- [Schritt 2](#)

___

## 💻 Schritt 1 (Setup-Schritte)
## 🛠️ Schritt 2 (praktische Übung)
## 📖 Schritt 3 (Theorie-Hintergrund)

...

___
___
[Breadcrumb-Navigation]  # Gleiche Leiste wie oben
___
___
```

### Breadcrumb-Navigation

**Muss exakt so sein** – inklusive Leerzeichen um `•` und Fettung der aktuellen Übung:

```
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • **Exercise 2** • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
```

Die Breadcrumb muss **sowohl in der ersten als auch in der letzten Zeile (vor den abschließenden `___`)**

### Erlaubte Emojis (aus prerequisites.md)

| Emoji | Bedeutung | Einsatz |
|---|---|---|
| 💡 | Tipp, Merksatz | Wichtige Hinweise |
| ⚠️ | Warnung | Stolperfallen |
| ❗ | Wichtiger Hinweis | Dringende Info |
| 🔍 | Detail / Genau hinschauen | Vertiefung |
| 🏁 | Zielflagge | Ergebnis, Abschluss |
| 🛠️ | Vorbereitung/Setup | Praxisschritte |
| 🧩 | Modul / Zusammenhang | Struktur |
| 📋 | Navigation / Übersicht | Inhaltsverzeichnis |
| 📖 | Theorie | Hintergrundwissen |
| 💻 | Praxis-Schritte | Terminal-Befehle |
| ✅ | Richtig | Erfolgsmeldung |

### Codeblöcke

- Bash-Befehle: ` ```bash ` (kein `shell`)
- JSON: ` ```json `
- FSH: ` ```bash ` oder ` ```fsh `
- Terminal-Ausgabe: ` ```text ` oder ` ``` `
- Erwartete Ergebnisse als Kommentar oder separater Block

### Querverweise

- Auf andere Übungen: `[Exercise 1](exercise-1.md)` (mit geschütztem Leerzeichen vor der Nummer)
- Auf externe URLs: Normale Markdown-Links
- Auf Abschnitte innerhalb der Datei: `[Schrittname](#abschchnitt-id)`

---

## 5. Ausführungshinweise für Agenten

### Arbeitsablauf

1. **Vorbereitung:** `git checkout develop` und `git pull`
2. **Änderungen umfassen immer:** Übungsdatei (`exercises/exercise-N.md`) + Lösungsdateien (`tmp-solution_exercise-N/`)
3. **Nach Fertigstellung:**
   - `bash -n` auf alle neuen `.sh`-Dateien
   - Prüfen ob Breadcrumbs oben und unten identisch sind
   - Prüfen ob alle internen Links funktionieren (existierende Dateien)
   - Debugger-Task mit Acceptance Criteria ausführen (Kriterien vorher festlegen)
4. **Commit-Nachricht:** Kurz, beschreibend, z. B. `Vervollständigt Exercise 3 – Query von KDS-Daten`

### Verboten

- ❌ Niemals auf `main` commitieren oder pushen
- ❌ Niemals die bestehende Emoji-Palette erweitern (neue Emojis nur nach Absprache)
- ❌ Niemals bestehende Übungen inhaltlich verändern (nur ergänzen/reparieren wenn explizit angewiesen)
- ❌ Keine neuen Abhängigkeiten einführen (immer mit Standard-Tools arbeiten: jq, curl, sushi, docker compose)
- ❌ `exercises/figures/` – keine Binärdateien ohne Absprache

---

## 6. Nächste Schritte (Backlog)

1. **Exercise 3 – Query von KDS-Daten** (als nächstes)
   - Inhalt: Strukturierte Abfragen auf die in Ex 2 geladenen Musterdaten
   - Schwerpunkte: FHIR Search Parameter, Chaining, `_include`, `_revinclude`, `_filter`
   - Ausblick auf TORCH
2. **Exercise 4** – Terminologieserver (Blaze TermServ)
3. **Exercise 5** – MII FHIR Validator
4. **Exercise 6** – Ergebnisse interpretieren
5. **Exercise 7** – Ausblick (Lizenzen, Alternativen)

---

## 7. Datenquellen (Referenzen)

| Ressource | URL |
|---|---|
| Musterdatenspende DIZ | `https://github.com/medizininformatik-initiative/musterdatenspende-diz` |
| MII-Testdaten | `https://github.com/medizininformatik-initiative/mii-testdata` |
| Blaze (FHIR Server) | `https://github.com/samply/blaze` / `samply/blaze:latest` |
| MII FHIR Validator | `https://github.com/medizininformatik-initiative/mii-fhir-validator` |
| KDS-Module (GitHub) | `https://github.com/orgs/medizininformatik-initiative/repositories?q=kerndatensatz` |
| FHIR Shorthand Docs | `https://hl7.org/fhir/uv/shorthand/overview.html` |
| SUSHI Docs | `https://fshschool.org/docs/SUSHI/` |
