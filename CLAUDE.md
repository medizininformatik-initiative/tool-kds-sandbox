# CLAUDE.md

Projektkontext, Status und Regeln für die Arbeit an diesem Repository. Diese Datei ist die einzige Quelle dafür – bei Statusänderungen hier mitpflegen.

> **Stand:** 2026-11-05

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

`solution-exercise-5/check_codesystems.sh` fasst die beiden Befehle aus Übung 5, Schritt 5 zusammen (Terminologieserver als Parameter, Standard tx.fhir.org); wird in Übung 6, Schritt 1c für den Vergleich FHIRsmith/Ontoserver wiederverwendet. Bei Änderungen an Schritt 5 mitziehen.

`solution-exercise-2/blaze/docker-compose.yml` ist eine Kopie des Compose-Blocks aus Übung 2 – bei Änderungen mitziehen.

`solution-exercise-6/` enthält die Konfigurationsdateien aus Übung 6 (`terminology-server/`, `validator/`) als Kopie der Code-Blöcke – bei Änderungen in `exercises/exercise-6.md` mitziehen.

`solution-exercise-1/` und `solution-exercise-2/` enthalten dasselbe `ExampleIG/`-Projekt – Änderungen an beiden Stellen nachziehen. Bewusste Ausnahmen (Übungen bauen aufeinander auf): `Organization-beispiel-labor.fsh` und `* id = "example-patient"` in `patient.fsh` gibt es nur in `solution-exercise-2/`.

## Gemeinsamer Kontext der Übungen

- Laufzeitumgebung der Lernenden: Linux oder WSL2, Werkzeuge `sushi` (npm `fsh-sushi`), Java + IG Publisher, `docker compose`, `curl`, `jq`. Keine weiteren Abhängigkeiten einführen.
- Pfade in den Übungen: `~/tool-kds-sandbox`, `~/musterdatenspende-diz`; keine nutzerspezifischen Absolutpfade.
- Ports der Lernenden (alles `localhost`): Blaze `8080`, FHIRsmith (Übung 6) `8081`, MII FHIR Validator (Übung 6) `8082`; der Ontoserver-Proxy aus Übung 6, Schritt 1b liegt auf `8083`. Blaze und Validator sind auf `127.0.0.1` gebunden (Entscheidung 2026-11-05: Dienste mit Daten bzw. Schreibzugriff nicht ins Netz; FHIRsmith bleibt ohne Bindung, damit der Validator ihn über `host.docker.internal` erreicht). 2026-11-05 auf dem GWDG-Server getestet: Blaze und Validator laufen mit `127.0.0.1`, Validator antwortet (Patient-Test → `dom-6`-Warnung). Auf einem externen Testserver Blaze/Validator daher per SSH-Tunnel ansprechen oder lokal die Bindung entfernen. Das Setup des Autors weicht teils ab (externer Server statt `localhost`) – Übungen trotzdem für `localhost` schreiben und bei Bedarf einen Hinweis für abweichende Adressen geben. GWDG-Testserver: `ens3` hat MTU 1450 → Docker per `/etc/docker/daemon.json` auf MTU 1450 stellen, sonst brechen Downloads aus Containern ab (`ECONNRESET`). Nicht in die Übungen aufnehmen (betrifft Lernende auf `localhost` normalerweise nicht).
- FHIR-Server ist **Blaze** (`samply/blaze`, `http://localhost:8080/fhir`, gestartet per `docker compose up -d` aus Übung 2). Blaze erzwingt referenzielle Integrität und lässt sich nicht abschalten – das prägt Übung 3.
- Terminologieserver: Übung 5 nutzt **tx.fhir.org**, Übung 6 einen eigenen **FHIRsmith** (für den Validator) und optional den **MII Ontoserver** (nur `curl` über Proxy). Alle Terminologie-Befehle nutzen die Shell-Variable `TX`. Siehe [Entscheidung: Terminologieserver](#entscheidung-terminologieserver-2026-11-04).
- Validator ist der **MII FHIR Validator** (Übung 6, Image `ghcr.io/medizininformatik-initiative/mii-fhir-validator:0.0.1-alpha.9`, `POST /validateResource`) mit `TX_SERVER` = Terminologieserver aus Übung 6, Schritt 1. Das Standard-Setup des Validators (Blaze-Terminologie mit SNOMED-CT-Releasedateien, 16 GB RAM) wird bewusst nicht verwendet.
- Datenquelle ist die **Musterdatenspende** (`medizininformatik-initiative/musterdatenspende-diz`) mit drei Standorten (UKSH, UKW, UKHD), nicht die MII-Testdaten.

## Architekturentscheidungen

| Entscheidung | Begründung |
| --- | --- |
| **Musterdatenspende statt MII-Testdaten** | Enthält echte DIZ-Ausprägungen (UKHD, UKSH, UKW), zeigt Heterogenität. Testdaten sind nur technisch/strukturell. |
| **Blaze statt HAPI** | Leichtgewichtig, Docker, kein Java-Build nötig. Aber: referenzielle Integrität lässt sich nicht abschalten. |
| **Blaze-Image `samply/blaze:main` (ungepinnt)** | Bewusst (2026-11-05): Lernende sollen keine veralteten Versionen installieren. Nicht auf ein Release pinnen. |
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

UKHD und UKW werden seit 2026-11-05 als regulärer Teil von Übung 3 (Abschnitt 8) dargestellt, nicht mehr „optional“: Übung 6, 4.2 (R51 mit `Diagnose|2024.0.0`, nur UKHD) und 4.4 (alle `|2024.0.0`-Diagnosen stammen aus UKHD/UKW; UKSH hat nur `|2025.0.0`) brauchen sie.

⚠️ `merge-bundles.sh` **verwirft die erste Eingabedatei** (`reduce inputs` ohne `jq -n`). Daher 271 statt 272 UKSH-Patienten und 3 statt 4 UKHD-Patienten. Der Bug liegt im Musterdatenspende-Repo; die Übungen beschreiben das tatsächliche Verhalten. Alle drei Standorte zusammen: 275 Patienten, zzgl. Testpatienten aus Übung 2.

## Projektstatus

| Übung | Status | Bemerkung |
| --- | --- | --- |
| Voraussetzungen | ✅ Fertig | 2026-11-02 gestrafft (Werkzeugtabelle, RAM 8/16 GB, Verweis auf `services.md`) |
| Übung 1 | ✅ Getestet | FSH-Profile, SUSHI, IG Publisher |
| Übung 2 | ✅ Getestet | Blaze starten, Ressourcen hochladen, FHIR Search |
| Übung 3 | ✅ Getestet | Upload aller drei Standorte; Upload-Ausgabe auf Status-Zählung umgestellt |
| Übung 4 | ✅ Getestet | Zahlen 2026-11-02 korrigiert; 2026-11-05 auf „alle drei Standorte geladen“ umgestellt (Werte auf GWDG-Server gemessen, ohne Testressourcen aus Übung 2); Patient-ID in 5.4 wählen die Lernenden selbst |
| Übung 5 | ✅ Getestet | 2026-11-04 neu aufgebaut und von Jenne getestet: Terminologie-Operationen an tx.fhir.org mit Codes aus Blaze, Download-Links der Codesysteme, Aufgabe zur Diagnose-Rolle (Profil über `meta.profile`/Simplifier, `$expand`) |
| Übung 6 | 🟡 Teilweise getestet | 2026-11-04 mit FHIRsmith komplett durchgespielt (Schritt 1a/1c, 2–4). 2026-11-05 Schritt 1 umgebaut (1a FHIRsmith starten → 1b Ontoserver über Proxy ausprobieren → 1c FHIRsmith prüfen); 1b noch nicht im neuen Ablauf getestet, siehe Offene Punkte |
| Übung 7 | 🟡 Test ausstehend | Arbeitet mit den Berichten aus Übung 6; holt `hb.json` (Laborwert) seit 2026-11-05 selbst (früher Übung 6, 4.3); Skript `solution-exercise-7/validate.sh`; 2026-11-04 Abschnitt „Versionen von Codesystemen und Profilen“ und Abschluss (aus gestrichener Übung 8) |

## Entscheidung: Terminologieserver (2026-11-04)

Es gibt **keinen zentralen Schulungsserver**. Ziel bleibt: Lernende sollen nicht stundenlang auf das Einlesen von Terminologien warten.

- **Übung 5** vermittelt die Terminologie-Operationen (`$lookup`, `$validate-code`, `$expand`) am öffentlichen **tx.fhir.org** mit Codes aus den Musterdaten in Blaze. tx.fhir.org kennt LOINC, SNOMED CT International, UCUM und die HL7-Codesysteme, aber **nicht** ICD-10-GM, OPS, ATC (BfArM), die `fhir.de`-Codesysteme der Basisprofile und die MII-Codesysteme (geprüft 2026-11-04 per `$validate-code`: „A definition for CodeSystem … could not be found“). Diese Grenze ist bewusst das Lernziel am Ende von Übung 5.
- **Übung 6** (Entscheidung 2026-11-05, sequentiell statt Auswahl A/B/C): **1a** alle starten einen eigenen FHIRsmith (ICD-10-GM, OPS, Alpha-ID-SE, ohne LOINC/SNOMED CT; Einlesen ca. 15 min). **1b** währenddessen, wer ein Client-Zertifikat hat: MII Ontoserver über den nginx-Proxy aus dem Repo des MII FHIR Validators ausprobieren (nur `docker compose up -d nginx`, Port `127.0.0.1:8083`; nur Entwicklung, keine Personendaten, keine Massenvalidierung). **1c** eigenen FHIRsmith prüfen. Der Validator (Schritt 2 ff., Übung 7) nutzt immer den eigenen FHIRsmith. Einordnung: zentraler Ontoserver für kleine Tests, eigener Server für die eigene Validierung. tx.fhir.org nur noch als Notlösung im Kommentar der Validator-Compose.
- LOINC- und SNOMED-CT-Import (mehrere Stunden) nur als Vertiefung in Übung 6 erwähnen, nicht in den Übungsablauf aufnehmen.
- Die Musterdatenspende ist öffentlich; bei `$validate-code` gehen nur Codes an tx.fhir.org. Trotzdem in Übung 5 auf „nie echte Patientendaten an öffentliche Server“ hinweisen.

## Offene Punkte

### Beim Test der Übungen 6 und 7

Test-Setup des Autors: Blaze und FHIRsmith auf einem eigenen Testserver statt `localhost`. Dafür `localhost:8080` durch dessen Blaze-Adresse ersetzen und in Übung 6 `TX`/`TX_SERVER` auf den FHIRsmith dort setzen. Das eigene Test-Setup mappt FHIRsmith auf Port 80/443 statt 8081.

- **Übung 6, Schritt 1:** FHIRsmith (1a) durchspielen (2026-11-04 auf GWDG-Server: Start lief durch, ca. 12 min, 2,8 GB Speicher – 4096 reicht); Neustart nach `stop`/`start` (2026-11-05): ca. 4,5 min, liest alle Terminologien neu ein (Pakete aus Cache), 2,3 GB, `$validate-code` für `R51` eingetragen. Übung 6, Schritt 2 (2026-11-04, GWDG-Server mit FHIRsmith): Validator startet; erster Start ca. 5 min (davon ca. 4 min stilles Kopieren des Paket-Caches), Bereit-Zeile eingetragen. Im Log harmlose Warnung `$cache-control … caching disabled` (FHIRsmith kennt den Modus `START_CACHE` nicht). Schritt 1b (2026-11-05, GWDG-Server, noch im alten Ablauf mit Repo-Validator): `.p12` → PEM per `openssl pkcs12` und Proxy → Ontoserver 6.25.3 funktionieren mit Nutzerzertifikat. `check_codesystems.sh` am Ontoserver (2026-11-05): LOINC/SNOMED CT bekannt, Ergebnis als Satz in 1c. Auffällig: ICD-10-GM `L89.09` → Ontoserver `Unknown code … version '2026'`, FHIRsmith (MII-Paket 2026.0.2) `true`, „Dekubitus, Stadium 1: Sonstige und nicht näher bezeichnete Lokalisationen“ – Ursache unklar, ggf. bei SU-TermServ melden; bewusst nicht in der Übung thematisiert. Im neuen Ablauf noch prüfen: nur `nginx` starten (`docker compose up -d nginx` mit kopierter `.env`, startet laut `--dry-run` nur `fhir-nginx`), Browser-Zugang. `fhir-nginx` zeigt `unhealthy` (Compose-Healthcheck prüft `localhost` → `[::1]`, nginx lauscht nur IPv4) – bewusst nicht in der Übung erwähnt; ggf. Issue beim MII FHIR Validator melden. Nicht auf nicht-öffentliche Repositories verweisen.
- **Übung 6, Schritt 4.4** (2026-11-05 neu, auf GWDG-Server getestet): „Wie gut sind die Diagnosen der Musterdaten?“ – 57 von 482 Conditions nennen `Diagnose|2024.0.0` (425 `|2025.0.0`); alle 57 mit erzwungenem `profile` geprüft: 55 fehlerfrei, `Diagnosis-010` und `Diagnosis-026` mit Code `Z11 U99.0!` (zwei ICD-Codes in einem Feld, ICD-Version 2021) → 2 Fehler (Unknown code + required-Binding). Ohne `profile` meldet der Validator `Unknown code` trotzdem (Codeprüfung unabhängig vom Profil), nur der required-Binding-Fehler fehlt. Lehre: unbekannte Profilversion → alle Profilregeln entfallen.
- **Übung 6, Ergebnisse mit FHIRsmith (2026-11-04):** Validator erreicht FHIRsmith über `host.docker.internal`; `-Xmx4g` reicht (ca. 1,6 GB im Leerlauf). Image `0.0.1-alpha.9` nutzt die Query-Parameter `profile` und `checkDisplay` (nicht `profiles`/`displayOption` wie in der aktuellen Doku; unbekannte Parameter → `Unable to process param`). Diagnose-Paket `kerndatensatz.diagnose#2025.0.1` in `IG_PARAMS` ergänzt. Profilversionen: `Diagnose|2025.0.0` wird mit Paket 2025.0.1 geprüft, `|2024.0.0` und `ObservationLab|2025.0.2` werden nicht gefunden → nur FHIR-Basis-Prüfung (Lehrpunkt in 4.2). Beispiel aus Übung 1 nutzte ein nicht existierendes MII-CodeSystem für `QuelleKlinischesBezugsdatum` → auf SNOMED CT 399445004 umgestellt. Prozedur- und andere Modulprofile sind nicht geladen (bewusst).
- **Übung 7:** `<!-- TODO beim Test -->`-Stellen und die Lösung der Einordnungsaufgabe mit echten Meldungstexten abgleichen; `validate.sh` gegen echten Validator testen.

### Inhaltlich offen

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
