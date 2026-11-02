# CLAUDE.md

Projektkontext, Status und Regeln für die Arbeit an diesem Repository. Diese Datei ist die einzige Quelle dafür – bei Statusänderungen hier mitpflegen.

> **Stand:** 2026-11-02

## Projekt

MII-Kerndatensatz-(KDS-)Schulungsumgebung für neue Mitarbeitende der DIZe (Projekt baseTrace). Zielgruppe: technisch orientierte Mitarbeitende, die FHIR-Daten und FHIR-Werkzeuge praktisch kennenlernen. Das Repo ist primär **deutschsprachiger Markdown-Lehrinhalt** plus Bash-/FSH-Musterlösungen – es gibt keinen Build, keine Tests und keinen Linter.

**Didaktisches Prinzip:** Lernende sollen Funktion und Nutzung kennenlernen, indem sie vorgegebene Befehle ausführen und daraus lernen – nicht, indem sie eigenen Code schreiben.

## Struktur

- `exercises/prerequisites.md`, `exercises/exercise-1.md` … `exercise-8.md` – die Übungen; jede baut auf der vorherigen auf (FSH/SUSHI → Blaze-Upload → Musterdaten laden → Query → Terminologieserver → Validator → Ergebnisse interpretieren → Ausblick).
- `solution-exercise-N/` – Musterlösung zur jeweiligen Übung (auf `develop` als Ordner). Die Übungstexte beschreiben den Zielzustand auf `main`, wo die Lösungen in Solution-Branches (`solution_exercise-N`) liegen sollen. Diese Hinweise nicht an den develop-Stand anpassen.
- `exercises/services.md` – Nachschlageseite aller Dienste (Ports, `docker-compose.yml`, Start/Prüfen). Die Compose-Blöcke dort sind **Kopien** aus Exercise 2, 5 und 6 – bei Änderungen an einer Übung hier nachziehen (und umgekehrt). Steht in der Breadcrumb direkt hinter Prerequisites.
- `README.md` – Kurzübersicht aller Übungen; Überschriften/Farbemojis müssen zu den Übungstiteln passen.
- `local_notes/` – per `.gitignore` ausgeschlossen, nicht committen.
- `exercises/figures/` – keine Binärdateien ohne Absprache.

`solution-exercise-1/` und `solution-exercise-2/` enthalten dasselbe `ExampleIG/`-Projekt – Änderungen an beiden Stellen nachziehen. Bewusste Ausnahmen (Übungen bauen aufeinander auf): `Organization-beispiel-labor.fsh` und `* id = "example-patient"` in `patient.fsh` gibt es nur in `solution-exercise-2/`.

## Gemeinsamer Kontext der Übungen

- Laufzeitumgebung der Lernenden: Linux oder WSL2, Werkzeuge `sushi` (npm `fsh-sushi`), Java + IG Publisher, `docker compose`, `curl`, `jq`. Keine weiteren Abhängigkeiten einführen.
- Pfade in den Übungen: `~/tool-kds-sandbox`, `~/musterdatenspende-diz`; keine nutzerspezifischen Absolutpfade.
- Ports der Lernenden (alles `localhost`): Blaze `8080`, FHIRsmith (Exercise 5) `8081`, MII FHIR Validator (Exercise 6) `8082`. Das Setup des Autors weicht teils ab (externer Server statt `localhost`) – Übungen trotzdem für `localhost` schreiben und bei Bedarf einen Hinweis für abweichende Adressen geben.
- FHIR-Server ist **Blaze** (`samply/blaze`, `http://localhost:8080/fhir`, gestartet per `docker compose up -d` aus Exercise 2). Blaze erzwingt referenzielle Integrität und lässt sich nicht abschalten – das prägt Exercise 3.
- Terminologieserver ist **FHIRsmith** (Exercise 5) mit ICD-10-GM, OPS und Alpha-ID-SE aus dem MII-TermServ-GitLab; LOINC und SNOMED CT sind bewusst nicht geladen.
- Validator ist der **MII FHIR Validator** (Exercise 6, Image `ghcr.io/medizininformatik-initiative/mii-fhir-validator:0.0.1-alpha.9`, `POST /validateResource`) mit `TX_SERVER` = FHIRsmith. Das Standard-Setup des Validators (Blaze-Terminologie mit SNOMED-CT-Releasedateien, 16 GB RAM) wird bewusst nicht verwendet.
- Datenquelle ist die **Musterdatenspende** (`medizininformatik-initiative/musterdatenspende-diz`) mit drei Standorten (UKSH, UKW, UKHD), nicht die MII-Testdaten.

## Architekturentscheidungen

| Entscheidung | Begründung |
| --- | --- |
| **Musterdatenspende statt MII-Testdaten** | Enthält echte DIZ-Ausprägungen (UKHD, UKSH, UKW), zeigt Heterogenität. Testdaten sind nur technisch/strukturell. |
| **Blaze statt HAPI** | Leichtgewichtig, Docker, kein Java-Build nötig. Aber: referenzielle Integrität lässt sich nicht abschalten. |
| **„Remove“ statt „Repair“ (`clean_bundle.sh`)** | Ressourcen mit nicht auflösbaren Referenzen werden iterativ entfernt. Das frühere `repair-bundle.sh` (Dummy-Ressourcen) wurde verworfen: zu komplex, Folgefehler. |
| **PUT statt POST (`convert_to_put.sh`)** | `merge-bundles.sh` erzeugt POST → Blaze vergibt neue IDs, Referenzen brechen. PUT auf `resourceType/id` erhält die IDs. |
| **`transaction` statt `batch` (`prepare_upload.sh`)** | UKW enthält zirkuläre Referenzen (Condition ↔ Encounter); im `batch` scheitert die Integritätsprüfung pro Eintrag mit HTTP 409. |
| **Doppelte IDs umbenennen** | UKW enthält `Observation/LabResult-000000335` und `-346` doppelt → Kollision bei PUT. `prepare_upload.sh` hängt ein Suffix an. |
| **UKHD wie UKSH behandeln** | Alle Dateien aus dem Zip werden per `merge-bundles.sh` zusammengeführt. |
| **HbA1c-Profil bleibt fachlich falsch** | Ex1 fixiert LOINC `4548-4` (Massenanteil, `%`) mit `mmol/mol`; richtig wäre `59261-8`. Wird in Ex7 als Beispiel für „Validator findet das nicht“ genutzt – **nicht korrigieren**. |

### Exercise-3-Pipeline (`solution-exercise-3/`)

Die Skripte bilden eine Kette; Ausgabedateinamen werden an den Eingabenamen angehängt:

1. `clean_bundle.sh <bundle>.json` → `<bundle>_cleaned.json` – entfernt iterativ Ressourcen mit nicht auflösbaren Referenzen.
2. `prepare_upload.sh <x>.json` → `<x>_prepared.json` – nur für `searchset`-Bundles (UKW): konvertiert zu `transaction` und benennt doppelte IDs um.
3. `convert_to_put.sh <x>.json` → `<x>_put.json` – POST → PUT mit `resourceType/id`.

Upload: `curl -X POST http://localhost:8080/fhir -H "Content-Type: application/fhir+json" --data @<datei>_put.json`. UKSH und UKHD werden vorher mit `bin/merge-bundles.sh` aus dem Musterdatenspende-Repo zu einem Transaction-Bundle zusammengeführt.

### Verifizierte Zahlen (2026-11-02)

Ermittelt mit den **echten Skripten** gegen den aktuellen Musterdatenspende-Stand (nicht per Python-Nachbau):

| Standort | Rohdaten | Original | Nach Bereinigung | Entfernt | Patienten |
| --- | --- | --- | --- | --- | --- |
| UKSH | Zip, 272 Dateien | 8.446 | 8.083 | 363 | 271 |
| UKHD | Zip, 4 Dateien | 1.371 | 823 | 548 | 3 |
| UKW | 1 `searchset`-Datei | 235 | 234 | 1 | 1 |

⚠️ `merge-bundles.sh` **verwirft die erste Eingabedatei** (`reduce inputs` ohne `jq -n`). Daher 271 statt 272 UKSH-Patienten und 3 statt 4 UKHD-Patienten. Der Bug liegt im Musterdatenspende-Repo; die Übungen beschreiben das tatsächliche Verhalten. Alle drei Standorte zusammen: 275 Patienten, zzgl. Testpatienten aus Exercise 2.

## Projektstatus

| Übung | Status | Bemerkung |
| --- | --- | --- |
| Prerequisites | ✅ Fertig | 2026-11-02 gestrafft (Werkzeugtabelle, RAM 8/16 GB, Verweis auf `services.md`) |
| Exercise 1 | ✅ Getestet | FSH-Profile, SUSHI, IG Publisher |
| Exercise 2 | ✅ Getestet | Blaze starten, Ressourcen hochladen, FHIR Search |
| Exercise 3 | ✅ Getestet | Upload aller drei Standorte; Upload-Ausgabe auf Status-Zählung umgestellt |
| Exercise 4 | ✅ Getestet | Zahlen 2026-11-02 korrigiert; Patient-ID in 5.4 wählen die Lernenden selbst |
| Exercise 5 | 🟡 Test läuft | FHIRsmith; erwartete Ausgaben fehlen noch |
| Exercise 6 | 🟡 Test ausstehend | Auf echten MII FHIR Validator umgestellt; erwartete Ausgaben als `<!-- TODO beim Test -->` markiert |
| Exercise 7 | 🟡 Test ausstehend | Arbeitet mit den Berichten aus Ex6; Skript `solution-exercise-7/validate.sh` |
| Exercise 8 | 🟡 Überarbeitet | Werkzeug- und Lizenztabellen korrigiert |

## Offene Punkte

### Beim Test von Exercise 5–7

- **Ex5:** Ende-zu-Ende-Test, erwartete Ausgaben eintragen; prüfen, ob `NODE_OPTIONS=--max-old-space-size=4096` reicht (eigenes Setup nutzt 8192).
- **Ex6:** Erreicht der Validator FHIRsmith über `host.docker.internal`? Reicht `-Xmx4g` mit 4 IGs? Wie reagiert er auf Profilversionen `|2025.0.x` in den Musterdaten bei geladenen 2026er-Paketen? Welche Meldung kommt bei LOINC (nicht auf FHIRsmith)? Ab welcher Logzeile ist der Validator bereit?
- **Ex7:** `<!-- TODO beim Test -->`-Stellen und die Lösung der Einordnungsaufgabe mit echten Meldungstexten abgleichen; `validate.sh` gegen echten Validator testen.

### Inhaltlich offen

- **Ex2:** Blaze-Image steht auf `samply/blaze:main` (ungepinnt) – auf ein Release festlegen (Stand 2026-11: `1.13.0`).
- **Ex3:** Umstrukturierung & Präsentation (laut Commit `8f54a4d` offen). Ausblick nennt noch „LOINC, SNOMED-CT importieren“ für Ex5 – passt nicht mehr.
- **Ex4, Abfrage 6.1:** Alle Patienten haben nur `deceasedBoolean`, kein `deceasedDateTime` – der Widerspruchs-Check ergibt deshalb strukturell immer 0.
- **Musterdatenspende:** `merge-bundles.sh`-Bug ggf. dort als Issue melden.
- **Allgemein:** Abschnitte „Nächste Schritte“ (Anfang) und „Ausblick“ (Ende) in jeder Übung vereinheitlichen. Exercise 3–8 nutzen Emojis außerhalb der Palette (z. B. 🚫 🧹 📤 🔄 📊 🎯 🔧 🔢 📜) – Bereinigung nur nach Absprache.
- **Beim Merge nach `main`:** Alle Übungen komplett neu durchtesten (Zahlen, Ausgaben, Dateinamen) und Beschreibungen an die Repo-Struktur angleichen. Wird erst dann gemeinsam entschieden – vorher nichts vorwegnehmen.

## Konventionen für Übungsdateien

- **Kopf und Fuß:** zwei `___`-Zeilen, Breadcrumb, zwei `___`-Zeilen. Breadcrumb verlinkt alle Seiten mit ` • ` als Trenner, die aktuelle Seite **fett ohne Link**; Kopf- und Fuß-Breadcrumb müssen identisch sein:
  `[Prerequisites](prerequisites.md) • [Dienste](services.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • **Exercise 3** • [Exercise 4](exercise-4.md) • …`
- **Aufbau:** H1 mit Farbemoji → „**Nächste Schritte:**“ (kurze Liste) → Einleitung mit Bezug zu vorherigen Übungen → 📋 Übersicht → Abschnitte → 🏁 Zusammenfassung/Ausblick.
- **Farbemoji** im H1 und in `README.md`: ⚪ Prerequisites, 🔵 1, 🟢 2, 🟡 3, 🟠 4, 🔴 5, 🟣 6, 🟤 7, ⚫ 8.
- **Abschnitts-Emojis** nur aus dieser Palette: 💡 Tipp · ⚠️ Warnung · ❗ Wichtig · 🔍 Genau hinschauen/Vertiefung · 🚀 Start/Ausblick · 🏁 Ergebnis · 🛠️ Setup/Aufgabe · 🧩 Zusammenhang · 📋 Übersicht · 📌 Fixpunkt · 📖 Theorie · 💻 Praxis · ✅ Richtig · ❌ Falsch. Neue Emojis nur nach Absprache.
- **Codeblöcke:** `bash` für Befehle (nicht `shell`), `json`, `yaml`, `fsh` (alternativ `bash`), `text` für Ausgaben. Erwartete Ergebnisse als Kommentar (`# → …`) oder eigener `text`-Block.
- **Anker:** Bei Überschriften mit Emoji explizite `<a id="..."></a>` setzen (siehe Exercise 5–8).
- **Lösungsskripte** gehören nach `solution-exercise-N/`, nicht in die Übungsdatei eingebettet.
- **Übungstexte** übernehmen einzelne Blöcke aus externen Anleitungen; Skripte kommen erst nach Absprache in die `solution-exercise-N`-Ordner.

## Arbeitsablauf

1. Vorher: `git checkout develop && git pull`
2. Bestehende Übungsinhalte nur ändern, wenn explizit gewünscht; ansonsten ergänzen.
3. Erwartete Zahlen und Ausgaben möglichst mit den echten Skripten bzw. gegen einen echten Server ermitteln, nicht per Nachbau; nicht Getestetes als `<!-- TODO beim Test -->` markieren.
4. Nach Änderungen prüfen:
   - `bash -n` auf alle neuen oder geänderten `.sh`-Dateien
   - Breadcrumbs oben und unten identisch
   - Geänderte `docker-compose.yml` in der Übung und in `exercises/services.md` gleich
   - Interne Links und Anker funktionieren
   - Dateinamen in Kommentaren (`# → erzeugt: …`) stimmen mit der Skriptausgabe überein
   - `README.md` und Status/offene Punkte in dieser Datei aktualisiert
5. Commit-Nachricht kurz und beschreibend, z. B. `Ex4 - Zahlen korrigiert`.

### Nützliche Befehle

```bash
bash -n solution-exercise-3/*.sh                   # Syntaxcheck der Skripte
cd solution-exercise-1/ExampleIG && sushi .        # FSH → FHIR-Ressourcen
cd solution-exercise-1/ExampleIG && ./_build.sh    # IG Publisher (lädt publisher.jar nach)
```

💡 Unter Windows ist `jq` meist nicht installiert – die Skripte aus `solution-exercise-3/` dort per WSL prüfen.

## Git

- Arbeit auf `develop`; `main` nur für Releases – **nie** direkt auf `main` committen oder pushen.
- Parallel-Repo `mii-kds-sandbox_setup-repo` (DevContainer/Codespace-Setup) wird später integriert.

## Referenzen

| Ressource | URL |
| --- | --- |
| Musterdatenspende DIZ | https://github.com/medizininformatik-initiative/musterdatenspende-diz |
| Blaze | https://github.com/samply/blaze |
| FHIRsmith | https://github.com/HealthIntersections/FHIRsmith |
| MII FHIR Validator | https://github.com/medizininformatik-initiative/mii-fhir-validator |
| KDS-Module | https://github.com/orgs/medizininformatik-initiative/repositories?q=kerndatensatz |
| FHIR Shorthand | https://hl7.org/fhir/uv/shorthand/overview.html |
| SUSHI | https://fshschool.org/docs/SUSHI/ |
