# CLAUDE.md

Projektkontext, Status und Regeln für die Arbeit an diesem Repository. Diese Datei ist die einzige Quelle dafür – bei Statusänderungen hier mitpflegen.

> **Stand:** 2026-11-04

## Projekt

MII-Kerndatensatz-(KDS-)Schulungsumgebung für neue Mitarbeitende der DIZe (Projekt baseTrace). Zielgruppe: technisch orientierte Mitarbeitende, die FHIR-Daten und FHIR-Werkzeuge praktisch kennenlernen. Das Repo ist primär **deutschsprachiger Markdown-Lehrinhalt** plus Bash-/FSH-Musterlösungen – es gibt keinen Build, keine Tests und keinen Linter.

**Didaktisches Prinzip:** Lernende sollen Funktion und Nutzung kennenlernen, indem sie vorgegebene Befehle ausführen und daraus lernen – nicht, indem sie eigenen Code schreiben.

## Struktur

- `exercises/prerequisites.md`, `exercises/exercise-1.md` … `exercise-7.md` – die Übungen; jede baut auf der vorherigen auf (FSH/SUSHI → Blaze-Upload → Musterdaten laden → Query → Terminologie-Operationen → Terminologieserver + Validator → Ergebnisse interpretieren). Jede Übung hat ein eigenes Lernziel mit praktischem Anteil; reine Ausblick-/Theorie-Übungen gibt es bewusst nicht (die frühere Übung 8 „Ausblick“ wurde 2026-11-04 gestrichen, relevante Inhalte stecken in Übung 5–7).
- `solution-exercise-N/` – Musterlösung zur jeweiligen Übung (auf `develop` als Ordner). Die Übungstexte beschreiben den Zielzustand auf `main`, wo die Lösungen in Solution-Branches (`solution_exercise-N`) liegen sollen. Diese Hinweise nicht an den develop-Stand anpassen.
- `exercises/services.md` – Nachschlageseite aller Dienste (Ports, `docker-compose.yml`, Start/Prüfen). Die Compose-Blöcke dort sind **Kopien** aus den Übungen 2, 5 und 6 – bei Änderungen an einer Übung hier nachziehen (und umgekehrt). Steht in der Breadcrumb direkt hinter Voraussetzungen.
- `README.md` – Kurzübersicht aller Übungen; Überschriften/Farbemojis müssen zu den Übungstiteln passen.
- `local_notes/` – per `.gitignore` ausgeschlossen, nicht committen.
- `exercises/figures/` – keine Binärdateien ohne Absprache.

`solution-exercise-1/` und `solution-exercise-2/` enthalten dasselbe `ExampleIG/`-Projekt – Änderungen an beiden Stellen nachziehen. Bewusste Ausnahmen (Übungen bauen aufeinander auf): `Organization-beispiel-labor.fsh` und `* id = "example-patient"` in `patient.fsh` gibt es nur in `solution-exercise-2/`.

## Gemeinsamer Kontext der Übungen

- Laufzeitumgebung der Lernenden: Linux oder WSL2, Werkzeuge `sushi` (npm `fsh-sushi`), Java + IG Publisher, `docker compose`, `curl`, `jq`. Keine weiteren Abhängigkeiten einführen.
- Pfade in den Übungen: `~/tool-kds-sandbox`, `~/musterdatenspende-diz`; keine nutzerspezifischen Absolutpfade.
- Ports der Lernenden (alles `localhost`): Blaze `8080`, FHIRsmith (Übung 6, optional) `8081`, MII FHIR Validator (Übung 6) `8082`; der Ontoserver-Proxy aus Übung 6, Schritt 1b liegt auf `8083`. Das Setup des Autors weicht teils ab (externer Server statt `localhost`) – Übungen trotzdem für `localhost` schreiben und bei Bedarf einen Hinweis für abweichende Adressen geben.
- FHIR-Server ist **Blaze** (`samply/blaze`, `http://localhost:8080/fhir`, gestartet per `docker compose up -d` aus Übung 2). Blaze erzwingt referenzielle Integrität und lässt sich nicht abschalten – das prägt Übung 3.
- Terminologieserver: Übung 5 nutzt **tx.fhir.org**, Übung 6 einen eigenen **FHIRsmith** oder den **MII Ontoserver**. Alle Terminologie-Befehle nutzen die Shell-Variable `TX`. Siehe [Entscheidung: Terminologieserver](#entscheidung-terminologieserver-2026-11-04).
- Validator ist der **MII FHIR Validator** (Übung 6, Image `ghcr.io/medizininformatik-initiative/mii-fhir-validator:0.0.1-alpha.9`, `POST /validateResource`) mit `TX_SERVER` = Terminologieserver aus Übung 6, Schritt 1. Das Standard-Setup des Validators (Blaze-Terminologie mit SNOMED-CT-Releasedateien, 16 GB RAM) wird bewusst nicht verwendet.
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
| **HbA1c-Profil bleibt fachlich falsch** | Übung 1 fixiert LOINC `4548-4` (Massenanteil, `%`) mit `mmol/mol`; richtig wäre `59261-8`. Wird in Übung 7 als Beispiel für „Validator findet das nicht“ genutzt – **nicht korrigieren**. |

### Übung-3-Pipeline (`solution-exercise-3/`)

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

⚠️ `merge-bundles.sh` **verwirft die erste Eingabedatei** (`reduce inputs` ohne `jq -n`). Daher 271 statt 272 UKSH-Patienten und 3 statt 4 UKHD-Patienten. Der Bug liegt im Musterdatenspende-Repo; die Übungen beschreiben das tatsächliche Verhalten. Alle drei Standorte zusammen: 275 Patienten, zzgl. Testpatienten aus Übung 2.

## Projektstatus

| Übung | Status | Bemerkung |
| --- | --- | --- |
| Voraussetzungen | ✅ Fertig | 2026-11-02 gestrafft (Werkzeugtabelle, RAM 8/16 GB, Verweis auf `services.md`) |
| Übung 1 | ✅ Getestet | FSH-Profile, SUSHI, IG Publisher |
| Übung 2 | ✅ Getestet | Blaze starten, Ressourcen hochladen, FHIR Search |
| Übung 3 | ✅ Getestet | Upload aller drei Standorte; Upload-Ausgabe auf Status-Zählung umgestellt |
| Übung 4 | ✅ Getestet | Zahlen 2026-11-02 korrigiert; Patient-ID in 5.4 wählen die Lernenden selbst |
| Übung 5 | ✅ Getestet | 2026-11-04 neu aufgebaut und von Jenne getestet: Terminologie-Operationen an tx.fhir.org mit Codes aus Blaze, Download-Links der Codesysteme, Aufgabe zur Diagnose-Rolle (Profil über `meta.profile`/Simplifier, `$expand`) |
| Übung 6 | 🟡 Test ausstehend | 2026-11-04: Schritt 1 Terminologieserver (FHIRsmith / MII Ontoserver / tx.fhir.org) ergänzt; erwartete Ausgaben als `<!-- TODO beim Test -->` markiert |
| Übung 7 | 🟡 Test ausstehend | Arbeitet mit den Berichten aus Übung 6; Skript `solution-exercise-7/validate.sh`; 2026-11-04 Abschnitt „Versionen von Codesystemen und Profilen“ und Abschluss (aus gestrichener Übung 8) |

## Entscheidung: Terminologieserver (2026-11-04)

Es gibt **keinen zentralen Schulungsserver**. Ziel bleibt: Lernende sollen nicht stundenlang auf das Einlesen von Terminologien warten.

- **Übung 5** vermittelt die Terminologie-Operationen (`$lookup`, `$validate-code`, `$expand`) am öffentlichen **tx.fhir.org** mit Codes aus den Musterdaten in Blaze. tx.fhir.org kennt LOINC, SNOMED CT International, UCUM und die HL7-Codesysteme, aber **nicht** ICD-10-GM, OPS, ATC (BfArM), die `fhir.de`-Codesysteme der Basisprofile und die MII-Codesysteme (geprüft 2026-11-04 per `$validate-code`: „A definition for CodeSystem … could not be found“). Diese Grenze ist bewusst das Lernziel am Ende von Übung 5.
- **Übung 6** beginnt mit dem Bereitstellen eines Terminologieservers für den Validator: **A** eigener FHIRsmith (empfohlen; ICD-10-GM, OPS, Alpha-ID-SE, ohne LOINC/SNOMED CT), **B** MII Ontoserver über die Ontoserver-Konfiguration aus dem Repo des MII FHIR Validators (mTLS-Client-Zertifikat, nur Entwicklung, keine Personendaten, keine Massenvalidierung), **C** tx.fhir.org als schnelle Notlösung (ohne deutsche Klassifikationen).
- LOINC- und SNOMED-CT-Import (mehrere Stunden) nur als Vertiefung in Übung 6 erwähnen, nicht in den Übungsablauf aufnehmen.
- Die Musterdatenspende ist öffentlich; bei `$validate-code` gehen nur Codes an tx.fhir.org. Trotzdem in Übung 5 auf „nie echte Patientendaten an öffentliche Server“ hinweisen.

## Offene Punkte

### Beim Test der Übungen 6 und 7

Test-Setup des Autors: Blaze und FHIRsmith auf einem eigenen Testserver statt `localhost`. Dafür `localhost:8080` durch dessen Blaze-Adresse ersetzen und in Übung 6 `TX`/`TX_SERVER` auf den FHIRsmith dort setzen. Das eigene Test-Setup mappt FHIRsmith auf Port 80/443 statt 8081.

- **Übung 6, Schritt 1:** FHIRsmith (1a) durchspielen, Dauer des ersten Starts messen, prüfen ob `NODE_OPTIONS=--max-old-space-size=4096` reicht (eigenes Setup nutzt 8192), `$validate-code` für `C20` eintragen. Ontoserver-Weg (1b) nur mit Client-Zertifikat testbar. Nicht auf nicht-öffentliche Repositories verweisen.
- **Übung 6, ab Schritt 2:** Erreicht der Validator FHIRsmith über `host.docker.internal`? Reicht `-Xmx4g` mit 4 IGs? Wie reagiert er auf Profilversionen `|2025.0.x` in den Musterdaten bei geladenen 2026er-Paketen? Welche Meldung kommt bei LOINC (nicht auf FHIRsmith)? Ab welcher Logzeile ist der Validator bereit?
- **Übung 7:** `<!-- TODO beim Test -->`-Stellen und die Lösung der Einordnungsaufgabe mit echten Meldungstexten abgleichen; `validate.sh` gegen echten Validator testen.

### Inhaltlich offen

- **Übung 2:** Blaze-Image steht auf `samply/blaze:main` (ungepinnt) – auf ein Release festlegen (Stand 2026-11: `1.13.0`).
- **Übung 3:** Umstrukturierung & Präsentation (laut Commit `8f54a4d` offen).
- **Übung 4, Abfrage 6.1:** Alle Patienten haben nur `deceasedBoolean`, kein `deceasedDateTime` – der Widerspruchs-Check ergibt deshalb strukturell immer 0.
- **Ideen für weitere Übungen** (aus der gestrichenen Übung 8; nur mit eigenem praktischen Lernziel aufnehmen): Pseudonymisierung von FHIR-Ressourcen (z. B. FHIR Pseudonymizer), Auswertung mit Skripten externer Forschender (R/Python), Datenausleitung mit TORCH und DIMP/DUP, Consent-Prüfung bei der Ausleitung, `CapabilityStatement` eines Servers lesen.
- **Musterdatenspende:** `merge-bundles.sh`-Bug ggf. dort als Issue melden.
- **Allgemein:** Abschnitte „Nächste Schritte“ (Anfang) und „Ausblick“ (Ende) in jeder Übung vereinheitlichen. Die Übungen 3–7 nutzen Emojis außerhalb der Palette (z. B. 🚫 🧹 📤 🔄 📊 🎯 🔧 🔢 📜) – Bereinigung nur nach Absprache.
- **Beim Merge nach `main`:** Alle Übungen komplett neu durchtesten (Zahlen, Ausgaben, Dateinamen) und Beschreibungen an die Repo-Struktur angleichen. Wird erst dann gemeinsam entschieden – vorher nichts vorwegnehmen.

## Konventionen für Übungsdateien

- **Sprache:** Alle Übungen sind deutsch – auch Linktexte und Navigation („Voraussetzungen“, „Dienste“, Kurznamen der Übungen). Dateinamen (`prerequisites.md`, `exercise-N.md`, `services.md`) bleiben englisch.
- **Kopf und Fuß:** zwei `___`-Zeilen, Breadcrumb, zwei `___`-Zeilen. Breadcrumb verlinkt alle Seiten mit ` • ` als Trenner, die aktuelle Seite **fett ohne Link**; Kopf- und Fuß-Breadcrumb müssen identisch sein:
  `[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • **3 · Musterdaten laden** • [4 · Daten abfragen](exercise-4.md) • …`
- **Kurznamen der Übungen** (Nummer + Nomen + Verb, Trenner `·`): 1 · Profil erstellen, 2 · FHIR-Server starten, 3 · Musterdaten laden, 4 · Daten abfragen, 5 · Codes prüfen, 6 · Ressourcen validieren, 7 · Berichte auswerten. In der Navigationsleiste ohne „Übung“, in Links im Fließtext als `[Übung N · Kurzname](exercise-N.md)`. Die H1-Titel der Übungen sind länger und dürfen abweichen.
- **Aufbau:** H1 mit Farbemoji → „**Nächste Schritte:**“ (kurze Liste) → Einleitung mit Bezug zu vorherigen Übungen → 📋 Übersicht → Abschnitte → 🏁 Zusammenfassung/Ausblick.
- **Farbemoji** im H1 und in `README.md`: ⚪ Voraussetzungen, 🔵 1, 🟢 2, 🟡 3, 🟠 4, 🔴 5, 🟣 6, 🟤 7.
- **Abschnitts-Emojis** nur aus dieser Palette: 💡 Tipp · ⚠️ Warnung · ❗ Wichtig · 🔍 Genau hinschauen/Vertiefung · 🚀 Start/Ausblick · 🏁 Ergebnis · 🛠️ Setup/Aufgabe · 🧩 Zusammenhang · 📋 Übersicht · 📌 Fixpunkt · 📖 Theorie · 💻 Praxis · ✅ Richtig · ❌ Falsch. Neue Emojis nur nach Absprache.
- **Codeblöcke:** `bash` für Befehle (nicht `shell`), `json`, `yaml`, `fsh` (alternativ `bash`), `text` für Ausgaben. Erwartete Ergebnisse als Kommentar (`# → …`) oder eigener `text`-Block.
- **Anker:** Bei Überschriften mit Emoji explizite `<a id="..."></a>` setzen (siehe Übungen 5–7).
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
5. Commit-Nachricht kurz und beschreibend, z. B. `Übung 4 - Zahlen korrigiert`.

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
