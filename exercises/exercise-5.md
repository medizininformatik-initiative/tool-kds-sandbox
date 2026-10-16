___
___
[Prerequisites](prerequisites.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • **Exercise 5** • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
___
___

# 🔴 Aufsetzen eines lokalen Terminologieservers

**Nächste Schritte:**

- Terminologieserver **FHIRsmith** per Docker Compose starten
- Deutsche Klassifikationen (ICD-10-GM, OPS, Alpha-ID-SE) laden
- Codes nachschlagen (`$lookup`), prüfen (`$validate-code`) und suchen (`$expand`)
- Diagnosecodes aus den Musterdaten in Blaze gegen den Terminologieserver prüfen

In den vorherigen Übungen hast du FHIR-Ressourcen in Blaze geladen und abgefragt. Dabei ging es um die **Struktur** der Daten. Ob ein Code wie `I10.90` in einer Diagnose aber tatsächlich existiert, in welcher Version er gilt und wie er heißt, weiß Blaze nicht. Dafür gibt es **Terminologieserver**: Sie kennen Codesysteme (z. B. ICD-10-GM) und ValueSets (Auswahllisten von Codes) und beantworten Fragen dazu über standardisierte FHIR-Operationen.

In dieser Übung setzt du mit [FHIRsmith](https://github.com/HealthIntersections/FHIRsmith) einen eigenen Terminologieserver auf. FHIRsmith ist dieselbe Software, die auch hinter dem öffentlichen HL7-Terminologieserver [tx.fhir.org](https://tx.fhir.org) läuft. Den Server brauchst du in [Exercise 6](exercise-6.md) für die Validierung.

___

📋 **Übersicht:**

- [Hintergrund: Terminologien und Terminologieserver](#hintergrund)
- [Aufbau von FHIRsmith](#aufbau)
- [Schritt 1: Klassifikationen herunterladen](#schritt-1)
- [Schritt 2: Konfiguration anlegen](#schritt-2)
- [Schritt 3: Server starten](#schritt-3)
- [Schritt 4: Terminologie-Operationen ausprobieren](#schritt-4)
- [Schritt 5: Diagnosen aus Blaze prüfen](#schritt-5)
- [Vertiefung: LOINC, SNOMED CT und HTTPS](#vertiefung)
- [Zusammenfassung und Ausblick](#zusammenfassung)

___

## <a id="hintergrund"></a>📖 Hintergrund: Terminologien und Terminologieserver

### Codesysteme im DIZ

| Codesystem | Herausgeber | Typische Verwendung im KDS | Beschaffung |
| --- | --- | --- | --- |
| **ICD-10-GM** | BfArM | Diagnosen (`Condition.code`) | Frei verfügbar |
| **OPS** | BfArM | Prozeduren (`Procedure.code`) | Frei verfügbar |
| **Alpha-ID-SE** | BfArM | Seltene Erkrankungen (`Condition.code`) | Frei verfügbar |
| **ATC** | BfArM / WHO | Wirkstoffe (`Medication.code`) | Frei verfügbar |
| **LOINC** | Regenstrief Institute | Laborwerte (`Observation.code`) | Kostenloser Account nötig |
| **SNOMED CT** | SNOMED International | Klinische Begriffe (viele Elemente) | Lizenz nötig (in DE über das BfArM) |
| **UCUM** | Regenstrief Institute | Maßeinheiten (`valueQuantity.code`) | Frei verfügbar |

> ⚠️ **Versionen:** Codesysteme ändern sich regelmäßig, die ICD-10-GM z. B. jährlich. Ein Code, der 2023 gültig war, kann 2026 fehlen oder anders heißen. Ein Terminologieserver kann mehrere Versionen parallel vorhalten.

### Was kann ein Terminologieserver?

Alle FHIR-Terminologieserver bieten dieselben Standard-Operationen an:

| Operation | Frage | Beispiel |
| --- | --- | --- |
| `$lookup` | Was bedeutet dieser Code? | ICD-10-GM `I10.90` → „Essentielle Hypertonie, nicht näher bezeichnet …“ |
| `$validate-code` | Gibt es diesen Code (in diesem ValueSet)? Passt der Anzeigetext? | Ist `I10.99` ein gültiger ICD-10-GM-Code? |
| `$expand` | Welche Codes enthält ein ValueSet? | Alle ICD-10-GM-Codes, die „Hypertonie“ enthalten |
| `$translate` | Wie lautet der Code in einem anderen System? | Mapping über eine ConceptMap |

### Terminologieserver im Überblick

| | tx.fhir.org | MII Ontoserver | FHIRsmith (lokal) |
| --- | --- | --- | --- |
| **Betreiber** | HL7 (öffentlich) | MII Service Unit Terminologie | Du selbst |
| **Software** | FHIRsmith | Ontoserver (CSIRO) | FHIRsmith |
| **Zugang** | Öffentlich, ohne Login | Client-Zertifikat nötig | Lokal, ohne Login |
| **Inhalt** | Internationale Terminologien | MII-/KDS-Terminologien | Was du lädst |
| **Einsatz** | Standard für IG Publisher und Validator | Entwicklung, keine Personendaten | Lernen, offline, eigene Tests |

> 💡 **Warum lokal?** Ein lokaler Server funktioniert offline, du bestimmst selbst die Versionen der Codesysteme, und es verlassen keine Daten deinen Rechner. Das ist wichtig, sobald du echte Daten prüfst.

___

## <a id="aufbau"></a>🧩 Aufbau von FHIRsmith

FHIRsmith ist ein Node.js-Server, den wir als Docker-Container starten. Er liest beim Start zwei Dateien aus seinem Datenordner:

```text
~/terminology-server/
├── docker-compose.yml          ← startet den Container (Port 8081)
└── data/                       ← Datenordner des Servers
    ├── config.json             ← WELCHE Module laufen (hier nur: Terminologieserver unter /fhir)
    ├── library.yml             ← WELCHE Terminologien geladen werden
    ├── de.bfarm.icd-10-gm/     ← heruntergeladene Pakete (Schritt 1)
    ├── de.bfarm.ops/
    └── de.bfarm.alpha-id-se/
```

Die `library.yml` ist das Herzstück: Jede Zeile ist eine Quelle für Terminologien. Manche bringt FHIRsmith selbst mit (`internal:`, `ucum:`), manche lädt er beim Start aus der FHIR-Paket-Registry (`npm:`), andere liest er aus einem lokalen Ordner (`folder:`).

___

## <a id="schritt-1"></a>💻 Schritt 1: Klassifikationen herunterladen

Die MII stellt ICD-10-GM, OPS und Alpha-ID-SE als fertige FHIR-Pakete bereit (aufbereitet aus den BfArM-Dateien). Lege einen eigenen Ordner für den Terminologieserver an und lade die Pakete herunter:

```bash
mkdir -p ~/terminology-server/data
cd ~/terminology-server

GITLAB="https://gitlab.com/api/v4/projects"

mkdir -p data/de.bfarm.icd-10-gm
curl -fsSL "$GITLAB/57608725/packages/npm/@mii-termserv/de.bfarm.icd-10-gm/-/@mii-termserv/de.bfarm.icd-10-gm-2026.0.2.tgz" \
  | tar -xzf - -C data/de.bfarm.icd-10-gm --strip-components=1

mkdir -p data/de.bfarm.ops
curl -fsSL "$GITLAB/57608812/packages/npm/@mii-termserv/de.bfarm.ops/-/@mii-termserv/de.bfarm.ops-2026.0.2.tgz" \
  | tar -xzf - -C data/de.bfarm.ops --strip-components=1

mkdir -p data/de.bfarm.alpha-id-se
curl -fsSL "$GITLAB/57608808/packages/npm/@mii-termserv/de.bfarm.alpha-id-se/-/@mii-termserv/de.bfarm.alpha-id-se-2026.0.0.tgz" \
  | tar -xzf - -C data/de.bfarm.alpha-id-se --strip-components=1
```

Prüfe, was angekommen ist:

```bash
ls data/de.bfarm.icd-10-gm/
```

> 🔍 **Genau hinschauen:** Ein FHIR-Paket ist ein `.tgz`-Archiv mit JSON-Dateien. Für die ICD-10-GM enthält es u. a. eine `CodeSystem`-Ressource mit allen Codes der Version 2026. `--strip-components=1` entfernt dabei den Ordner `package/`, der in jedem FHIR-Paket steckt.

___

## <a id="schritt-2"></a>💻 Schritt 2: Konfiguration anlegen

Lege die Datei `data/library.yml` an. Sie legt fest, welche Terminologien der Server bereitstellt:

```yaml
# Von hier lädt FHIRsmith Dateien nach, die nicht lokal vorliegen
base:
  url: https://packages2.fhir.org/packages

# Welche Terminologien stellt der Server bereit?
sources:
  # Im Server eingebaute Codesysteme: Sprachen (BCP-47) und Länder (ISO 3166)
  - internal:lang
  - internal:country
  # Maßeinheiten (UCUM) – die Definitionsdatei ist im Docker-Image enthalten
  - ucum:tx/data/ucum-essence.xml
  # FHIR-Pakete, die FHIRsmith beim Start selbst aus der Paket-Registry lädt
  - npm:hl7.terminology.r4#7.3.0
  - npm:de.medizininformatikinitiative.kerndatensatz.base#2027.0.0-ballot
  # Deutsche Klassifikationen des BfArM, in Schritt 1 heruntergeladen
  - folder:/app/data/de.bfarm.icd-10-gm
  - folder:/app/data/de.bfarm.ops
  - folder:/app/data/de.bfarm.alpha-id-se
```

> 💡 Die Pfade unter `folder:` beginnen mit `/app/data`, weil der Server sie **im Container** sieht. Dort wird dein Ordner `~/terminology-server/data` eingebunden (siehe `docker-compose.yml` in Schritt 3).

Lege die Datei `data/config.json` an. FHIRsmith kann vieles (u. a. Paket-Registry, Validator); wir schalten nur den Terminologieserver ein und machen ihn unter dem Pfad `/fhir` erreichbar:

```json
{
  "server": {
    "port": 3000
  },
  "modules": {
    "tx": {
      "enabled": true,
      "librarySource": "/app/data/library.yml",
      "endpoints": [
        {
          "path": "/fhir",
          "fhirVersion": "4.0",
          "context": null
        }
      ]
    }
  }
}
```

___

## <a id="schritt-3"></a>💻 Schritt 3: Server starten

Lege im Ordner `~/terminology-server` die Datei `docker-compose.yml` an:

```yaml
services:
  tx:
    image: "ghcr.io/healthintersections/fhirsmith:v0.16.1"
    environment:
      FHIRSMITH_DATA_DIR: /app/data
      NODE_OPTIONS: --max-old-space-size=4096
    ports:
      - "8081:3000"
    volumes:
      - "./data:/app/data"
```

> 💡 Blaze aus [Exercise 2](exercise-2.md) belegt Port 8080, der Terminologieserver läuft daher auf **Port 8081**. Beide Server können gleichzeitig laufen. `NODE_OPTIONS` erlaubt dem Server, bis zu 4 GB Arbeitsspeicher zu nutzen.

Starte den Server und verfolge den Start im Log:

```bash
cd ~/terminology-server
docker compose up -d
docker compose logs -f tx
```

Beim ersten Start lädt FHIRsmith die `npm:`-Pakete herunter und liest alle Terminologien ein. Das dauert einige Minuten. Der Server ist bereit, wenn diese Zeile erscheint:

```text
=== Server running on http://localhost:3000 ===
```

`localhost:3000` ist die Adresse im Container. Von deinem Rechner aus erreichst du den Server unter `http://localhost:8081`. Mit `Strg+C` beendest du die Log-Anzeige; der Server läuft weiter.

> 🔍 **Genau hinschauen:** Weiter oben im Log listet FHIRsmith jede geladene Quelle mit der Anzahl ihrer CodeSystems und ValueSets auf. Findest du ICD-10-GM, OPS und Alpha-ID-SE?

Prüfe abschließend, ob der Server antwortet:

```bash
curl -s http://localhost:8081/fhir/metadata | jq '{software: .software, fhirVersion: .fhirVersion}'
```

> 💡 Öffne `http://localhost:8081/fhir` auch im Browser. FHIRsmith bringt eine Weboberfläche mit, in der du die geladenen Codesysteme durchsehen kannst.

___

## <a id="schritt-4"></a>💻 Schritt 4: Terminologie-Operationen ausprobieren

Die URLs von Terminologie-Operationen enthalten oft Sonderzeichen. Mit `curl -G` und `--data-urlencode` übernimmt `curl` das korrekte Kodieren der Parameter. Die Operation steht in einfachen Anführungszeichen, damit die Shell `$lookup` nicht als Variable liest.

### 4.1 Code nachschlagen: `$lookup`

Was bedeutet der ICD-10-GM-Code `I10.90`?

```bash
curl -s -G 'http://localhost:8081/fhir/CodeSystem/$lookup' \
  --data-urlencode "system=http://fhir.de/CodeSystem/bfarm/icd-10-gm" \
  --data-urlencode "code=I10.90" \
  | jq -r '.parameter[] | select(.name=="name" or .name=="version" or .name=="display") | "\(.name): \(.valueString)"'
```

Die Antwort nennt Codesystem, Version und Anzeigetext (Display) des Codes.

Probiere dasselbe für einen OPS-Code:

```bash
curl -s -G 'http://localhost:8081/fhir/CodeSystem/$lookup' \
  --data-urlencode "system=http://fhir.de/CodeSystem/bfarm/ops" \
  --data-urlencode "code=5-470.11" \
  | jq -r '.parameter[] | select(.name=="name" or .name=="version" or .name=="display") | "\(.name): \(.valueString)"'
```

### 4.2 Code prüfen: `$validate-code`

Ein gültiger Code:

```bash
curl -s -G 'http://localhost:8081/fhir/CodeSystem/$validate-code' \
  --data-urlencode "url=http://fhir.de/CodeSystem/bfarm/icd-10-gm" \
  --data-urlencode "code=I10.90" \
  | jq -r '.parameter[] | select(.name=="result" or .name=="message" or .name=="display") | "\(.name): \(if has("valueBoolean") then .valueBoolean else .valueString end)"'
```

Ein Code, den es nicht gibt:

```bash
curl -s -G 'http://localhost:8081/fhir/CodeSystem/$validate-code' \
  --data-urlencode "url=http://fhir.de/CodeSystem/bfarm/icd-10-gm" \
  --data-urlencode "code=I10.99" \
  | jq -r '.parameter[] | select(.name=="result" or .name=="message" or .name=="display") | "\(.name): \(if has("valueBoolean") then .valueBoolean else .valueString end)"'
```

Ein gültiger Code mit falschem Anzeigetext:

```bash
curl -s -G 'http://localhost:8081/fhir/CodeSystem/$validate-code' \
  --data-urlencode "url=http://fhir.de/CodeSystem/bfarm/icd-10-gm" \
  --data-urlencode "code=I10.90" \
  --data-urlencode "display=Bluthochdruck" \
  | jq -r '.parameter[] | select(.name=="result" or .name=="message" or .name=="display") | "\(.name): \(if has("valueBoolean") then .valueBoolean else .valueString end)"'
```

> 🔍 **Genau hinschauen:** Vergleiche die drei Antworten. Wie unterscheidet sich `result`? Was steht in `message`? Genau diese Prüfungen führt später der Validator in [Exercise 6](exercise-6.md) für jeden Code in einer Ressource durch.

### 4.3 Codes suchen: `$expand`

`$expand` listet die Codes eines ValueSets auf. Jedes Codesystem hat ein „implizites“ ValueSet mit allen seinen Codes; dessen URL ist die Codesystem-URL mit angehängtem `?fhir_vs`. Mit `filter` durchsuchst du die Anzeigetexte:

```bash
curl -s -G 'http://localhost:8081/fhir/ValueSet/$expand' \
  --data-urlencode "url=http://fhir.de/CodeSystem/bfarm/icd-10-gm?fhir_vs" \
  --data-urlencode "filter=Hypertonie" \
  --data-urlencode "count=10" \
  | jq -r '.expansion.contains[] | "\(.code)\t\(.display)"'
```

> 💡 **Ausprobieren:** Ändere den Filter (z. B. `Diabetes`) oder suche mit `http://fhir.de/CodeSystem/bfarm/ops?fhir_vs` in den OPS-Codes.

___

## <a id="schritt-5"></a>🛠️ Schritt 5: Diagnosen aus Blaze prüfen

Jetzt verbindest du beide Server: In Blaze liegen seit [Exercise 3](exercise-3.md) die Musterdaten. Sind die ICD-10-GM-Codes darin gültig?

Hole dir zuerst einige Diagnosecodes aus Blaze:

```bash
curl -s "http://localhost:8080/fhir/Condition?_count=20&_elements=code" \
  | jq -c '.entry[].resource.code.coding[] | select(.system=="http://fhir.de/CodeSystem/bfarm/icd-10-gm") | {code, version}'
```

Die Ausgabe zeigt pro Diagnose den ICD-10-GM-Code und die Version, mit der kodiert wurde. Suche dir einen Code aus der Liste aus, setze ihn im folgenden Befehl anstelle von `I10.90` ein und prüfe ihn am Terminologieserver:

```bash
curl -s -G 'http://localhost:8081/fhir/CodeSystem/$validate-code' \
  --data-urlencode "url=http://fhir.de/CodeSystem/bfarm/icd-10-gm" \
  --data-urlencode "code=I10.90" \
  | jq -r '.parameter[] | select(.name=="result" or .name=="message" or .name=="display") | "\(.name): \(if has("valueBoolean") then .valueBoolean else .valueString end)"'
```

Wiederhole das mit zwei oder drei weiteren Codes.

> 🔍 **Genau hinschauen:** Die Musterdaten wurden teils mit älteren ICD-10-GM-Versionen kodiert (siehe `version`), auf dem Server liegt aber nur die Version 2026. Was bedeutet das, wenn ein Code inzwischen gestrichen wurde? Und welche Version sollte ein DIZ zum Prüfen verwenden?

> 💡 Im DIZ-Alltag prüft niemand Codes einzeln von Hand. Das übernimmt der Validator, der für jede Ressource automatisch den Terminologieserver befragt. Genau darum geht es in [Exercise 6](exercise-6.md).

___

## <a id="vertiefung"></a>🔍 Vertiefung: LOINC, SNOMED CT und HTTPS

Diese Punkte sind für die Übung nicht nötig, begegnen dir aber im DIZ-Alltag:

- **LOINC** erfordert einen kostenlosen Account bei [loinc.org](https://loinc.org/signup). FHIRsmith liest LOINC nicht direkt, sondern aus einer selbst erzeugten Datenbankdatei (`loinc_<version>.db`). Der FHIRsmith-Importer erstellt sie aus dem LOINC-Download; das dauert mehrere Stunden, ist aber nur einmal nötig. Eingebunden wird sie in der `library.yml` mit `- loinc:loinc_2.83.db`.
- **SNOMED CT** ist lizenzpflichtig. In Deutschland vergibt das [BfArM](https://www.bfarm.de/DE/Kodiersysteme/Terminologien/SNOMED-CT/_node.html) Lizenzen. Auch hier erzeugt der Importer zunächst eine Cache-Datei (`- snomed:sct_ger_<datum>.cache`); das dauert ebenfalls Stunden.
- **HTTPS:** Der IG Publisher akzeptiert Terminologieserver nur über HTTPS und lokale Adressen nur nach expliziter Freigabe in der `fhir-settings.json`. Dafür setzt man einen Reverse Proxy (z. B. nginx mit selbstsigniertem Zertifikat) vor FHIRsmith. Mehr dazu in [Exercise 6](exercise-6.md).

___

## <a id="zusammenfassung"></a>🏁 Zusammenfassung und Ausblick

| Schritt | Befehl |
| --- | --- |
| Server starten | `cd ~/terminology-server && docker compose up -d` |
| Start verfolgen | `docker compose logs -f tx` |
| Code nachschlagen | `curl -s -G 'http://localhost:8081/fhir/CodeSystem/$lookup' --data-urlencode "system=…" --data-urlencode "code=…"` |
| Code prüfen | `curl -s -G 'http://localhost:8081/fhir/CodeSystem/$validate-code' --data-urlencode "url=…" --data-urlencode "code=…"` |
| Codes suchen | `curl -s -G 'http://localhost:8081/fhir/ValueSet/$expand' --data-urlencode "url=…?fhir_vs" --data-urlencode "filter=…"` |
| Server stoppen | `cd ~/terminology-server && docker compose down` |

**Ausblick:**

- [Exercise 6](exercise-6.md): Ressourcen validieren und dabei den eigenen Terminologieserver nutzen
- [Exercise 7](exercise-7.md): Meldungen des Terminologieservers in Validierungsberichten verstehen
- [Exercise 8](exercise-8.md): Lizenzen und Versionierung von Codesystemen

___
___
[Prerequisites](prerequisites.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • **Exercise 5** • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
___
___
