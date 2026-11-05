___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • **6 · Ressourcen validieren** • [7 · Berichte auswerten](exercise-7.md)
___
___

# 🟣 Nutzen eines FHIR Validators

**Nächste Schritte:**

- Starte einen **eigenen Terminologieserver** (FHIRsmith) mit deutschen Klassifikationen und probiere – mit Client-Zertifikat – den zentralen **MII Ontoserver** aus
- Starte den **MII FHIR Validator** per Docker Compose und verbinde ihn mit deinem Terminologieserver
- Validiere deine HbA1c-Observation aus [Übung 1 · Profil erstellen](exercise-1.md) gegen das MII-Laborprofil
- Validiere einzelne Musterdaten aus Blaze, darunter die Auffälligkeiten aus [Übung 4 · Daten abfragen](exercise-4.md)

In [Übung 5 · Codes prüfen](exercise-5.md) hast du einzelne Codes am öffentlichen Terminologieserver tx.fhir.org geprüft – und gesehen, dass er ICD-10-GM, OPS und die Codesysteme der MII nicht kennt. Jetzt prüfst du **ganze Ressourcen** gegen die Profile des Kerndatensatzes. Dafür braucht der Validator einen Terminologieserver, der auch die deutschen Inhalte kennt.

___

📋 **Übersicht:**

- [Hintergrund: Was prüft ein Validator?](#hintergrund)
- [Aufbau: Drei Server, drei Ports](#aufbau)
- [Schritt 1: Terminologieserver bereitstellen](#schritt-1)
  - [1a: Eigenen Terminologieserver starten](#schritt-1a)
  - [1b (optional): MII Ontoserver ausprobieren](#schritt-1b)
  - [1c: Eigenen Terminologieserver prüfen](#schritt-1c)
- [Schritt 2: Validator starten](#schritt-2)
- [Schritt 3: Eigene Ressource validieren](#schritt-3)
- [Schritt 4: Musterdaten aus Blaze validieren](#schritt-4)
- [Vertiefung: Kommandozeile und Ausbau des Terminologieservers](#vertiefung)
- [Zusammenfassung und Ausblick](#zusammenfassung)

___

## <a id="hintergrund"></a>📖 Hintergrund: Was prüft ein Validator?

### Strukturelle Validierung vs. Conformance-Validierung

- **Strukturell** prüfen Webtools wie fhirtoolbox.com oder SUSHI beim Build: Ist das gültiges FHIR? Sie finden Syntaxfehler, falsche Datentypen, teilweise fehlende Pflichtfelder und Codes außerhalb fest eingebauter Listen (z. B. `gender`). Das ist der schnelle Check beim Schreiben.
- **Conformance-Validierung** (HL7 Validator, IG Publisher, MII FHIR Validator) prüft zusätzlich alles, was ein Profil vorgibt: Kardinalitäten, Invarianten (FHIRPath), Slicing. Codes gibt der Validator an einen **Terminologieserver** weiter. Der prüft, ob ein Code im CodeSystem existiert, zum gebundenen ValueSet gehört und, wenn gewünscht, zum Anzeigetext passt. So prüft man vor einem Release, in CI oder in der ETL-Strecke.

> ⚠️ **Grenzen:** Ein Validator prüft **nicht**, ob Inhalte fachlich plausibel sind (z. B. ein Laborwert von 300 g/dL Hämoglobin) oder ob Code und Einheit fachlich zusammenpassen. Ob referenzierte Ressourcen (z. B. `Patient/...`) tatsächlich existieren, prüft er bei einer einzelnen Ressource ebenfalls nicht. Das hat in [Übung 3 · Musterdaten laden](exercise-3.md) Blaze beim Upload übernommen.

### Welcher Validator für welchen Zweck?

Es gibt nicht *den einen* FHIR-Validator. Die meisten Werkzeuge nutzen im Kern denselben HL7-Validator (`validator_cli.jar`) und unterscheiden sich darin, wie man sie aufruft und wie sie vorkonfiguriert sind:

| Werkzeug | Aufruf | Typischer Einsatz | Kennst du aus |
| --- | --- | --- | --- |
| `$validate-code` am Terminologieserver | REST-Anfrage | Einzelnen Code prüfen | [Übung 5 · Codes prüfen](exercise-5.md) |
| IG Publisher | Build-Prozess | Profile und Beispiele eines eigenen IG prüfen (QA-Report) | [Übung 1 · Profil erstellen](exercise-1.md) |
| HL7 Validator (`validator_cli.jar`) | Kommandozeile | Beliebige Ressourcen gegen beliebige IGs, z. B. in CI | [Vertiefung](#vertiefung) |
| **MII FHIR Validator** | HTTP: `POST /validateResource` | **Ressourcen gegen die MII-KDS-Profile prüfen** | **diese Übung** |

Wir nutzen den [MII FHIR Validator](https://github.com/medizininformatik-initiative/mii-fhir-validator): den HL7-Validator im Server-Modus, als Docker-Image vorkonfiguriert mit den Paketen der MII-Kerndatensatz-Module. Validatoren auf derselben Basis liefern bei gleicher Konfiguration dieselben Ergebnisse. Unterschiede entstehen durch geladene Pakete, Versionen und den Terminologieserver.

___

## <a id="aufbau"></a>🧩 Aufbau: Drei Server, drei Ports

In dieser Übung arbeiten drei Server zusammen:

```text
                     Ressource (JSON)                    $validate-code, $expand
  curl  ─────────────────────────────────▶  Validator  ─────────────────────────▶  Terminologieserver
   ▲                                       :8082                                   (FHIRsmith :8081)
   │ GET Ressource
   │
 Blaze :8080  (Musterdaten aus Übung 3)
```

| Server | Port | Aus Übung | Aufgabe |
| --- | --- | --- | --- |
| Blaze | `8080` | [Übung 2 · FHIR-Server starten](exercise-2.md) | FHIR-Server mit den Musterdaten |
| Terminologieserver (FHIRsmith) | `8081` | diese Übung, [Schritt 1a](#schritt-1a) | Kennt die Codesysteme, z. B. ICD-10-GM, OPS, UCUM |
| MII FHIR Validator | `8082` | diese Übung, [Schritt 2](#schritt-2) | Prüft Ressourcen gegen Profile, fragt Codes beim Terminologieserver an |

**Optional, nur mit Client-Zertifikat:** In [Schritt 1b](#schritt-1b) startest du zusätzlich einen Proxy zum MII Ontoserver auf Port `8083`.

> 💡 **Eigenes Setup mit anderen Adressen?** Laufen einzelne Server bei dir nicht lokal (z. B. auf einem Server im Netz), ersetze `localhost` in den Befehlen durch dessen Adresse und setze `TX_SERVER` in Schritt 2 auf die URL deines Terminologieservers.

___

## <a id="schritt-1"></a>🛠️ Schritt 1: Terminologieserver bereitstellen

Der Validator gibt jede Code-Prüfung an **einen** Terminologieserver weiter. Für die Daten des Kerndatensatzes gibt es zwei Möglichkeiten:

| | MII Ontoserver | Eigener Terminologieserver (FHIRsmith) |
| --- | --- | --- |
| **Betrieb** | Zentral, von der SU-TermServ der MII | Auf deinem Rechner, später im DIZ |
| **Inhalt** | Die Terminologien der MII-Profile | Was du selbst lädst; in dieser Übung ICD-10-GM, OPS, Alpha-ID-SE, UCUM, HL7-Codesysteme, **ohne** LOINC und SNOMED CT |
| **Zugang** | Nur mit Client-Zertifikat | Keiner nötig |
| **Einsatz** | Kleine Tests während der Entwicklung | Eigene Validierung, z. B. in der ETL-Strecke |

Du lernst beide kennen:

1. **[Schritt 1a](#schritt-1a):** Du startest deinen eigenen FHIRsmith. Das Einlesen der Terminologien dauert ca. 15 Minuten.
2. **[Schritt 1b](#schritt-1b) (optional, nur mit Client-Zertifikat):** Währenddessen probierst du den MII Ontoserver aus. Ohne Zertifikat überspringst du diesen Schritt.
3. **[Schritt 1c](#schritt-1c):** Du prüfst deinen eigenen Server. Ihn nutzt der Validator ab [Schritt 2](#schritt-2).

> 💡 **Warum LOINC und SNOMED CT nicht im eigenen Server?** Beide lassen sich in FHIRsmith laden, ein Importer muss sie aber erst in eine Datenbankdatei umwandeln. Das dauert jeweils mehrere Stunden. Für die Übung verzichten wir darauf; im DIZ macht man das einmalig pro Version. Mehr dazu in der [Vertiefung](#vertiefung).

### <a id="schritt-1a"></a>💻 Schritt 1a: Eigenen Terminologieserver starten

FHIRsmith ist ein Node.js-Server, den wir als Docker-Container starten. Er liest beim Start zwei Dateien aus seinem Datenordner:

```text
~/terminology-server/
├── docker-compose.yml          ← startet den Container (Port 8081)
└── data/                       ← Datenordner des Servers
    ├── config.json             ← WELCHE Module laufen (hier nur: Terminologieserver unter /fhir)
    ├── library.yml             ← WELCHE Terminologien geladen werden
    ├── de.bfarm.icd-10-gm/     ← heruntergeladene Pakete
    ├── de.bfarm.ops/
    └── de.bfarm.alpha-id-se/
```

Die `library.yml` ist das Herzstück: Jede Zeile ist eine Quelle für Terminologien. Manche bringt FHIRsmith selbst mit (`internal:`, `ucum:`), manche lädt er beim Start aus der FHIR-Paket-Registry (`npm:`), andere liest er aus einem lokalen Ordner (`folder:`).

**1. Klassifikationen herunterladen.** Die MII stellt ICD-10-GM, OPS und Alpha-ID-SE als fertige FHIR-Pakete bereit (aufbereitet aus den BfArM-Dateien):

> 💡 **Woher kommen die Adressen?** Die Pakete liegen in der GitLab-Gruppe [gitlab.com/mii-termserv](https://gitlab.com/mii-termserv), ein Projekt pro Klassifikation. Die Zahl in der URL ist die Projekt-ID (steht auf der Projektseite), Paketname und Version findest du im Projekt unter **Deploy → Package registry**.

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

ls data/de.bfarm.icd-10-gm/
```

> 🔍 **Genau hinschauen:** Ein FHIR-Paket ist ein `.tgz`-Archiv mit JSON-Dateien. Für die ICD-10-GM enthält es u. a. eine `CodeSystem`-Ressource mit allen Codes der Version 2026. `--strip-components=1` entfernt dabei den Ordner `package/`, der in jedem FHIR-Paket steckt.

**2. Konfiguration anlegen.** Lege die Datei `data/library.yml` an. Sie legt fest, welche Terminologien der Server bereitstellt:

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
  # Deutsche Klassifikationen des BfArM, oben heruntergeladen
  - folder:/app/data/de.bfarm.icd-10-gm
  - folder:/app/data/de.bfarm.ops
  - folder:/app/data/de.bfarm.alpha-id-se
```

> 💡 Die Pfade unter `folder:` beginnen mit `/app/data`, weil der Server sie **im Container** sieht. Dort wird dein Ordner `~/terminology-server/data` eingebunden (siehe `docker-compose.yml` unten).

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

**3. Server starten.** Lege im Ordner `~/terminology-server` die Datei `docker-compose.yml` an. Port 8080 belegt schon Blaze, der Terminologieserver läuft daher auf **Port 8081**. `NODE_OPTIONS` erlaubt ihm bis zu 4 GB Arbeitsspeicher:

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

```bash
cd ~/terminology-server
docker compose up -d
docker compose logs -f tx
```

Beim Start lädt FHIRsmith die `npm:`-Pakete herunter und liest alle Terminologien ein. Das dauert etwa **15 Minuten**, den größten Teil davon braucht das Paket `hl7.terminology.r4`. Auch bei jedem weiteren Start, z. B. nach einem Neustart deines Rechners, liest FHIRsmith die Terminologien neu ein und antwortet erst danach. Das geht schneller, weil die Pakete schon heruntergeladen sind, dauert aber trotzdem etwa **5 Minuten**. Der Server ist bereit, wenn diese Zeile erscheint:


```text
=== Server running on http://localhost:3000 ===
```

`localhost:3000` ist die Adresse im Container. Von deinem Rechner aus erreichst du den Server unter `http://localhost:8081`. Mit `Strg+C` beendest du die Log-Anzeige; der Server läuft weiter.

> 🔍 **Genau hinschauen:** Weiter oben im Log listet FHIRsmith jede geladene Quelle mit der Anzahl ihrer CodeSystems und ValueSets auf. Findest du ICD-10-GM, OPS und Alpha-ID-SE?

Während FHIRsmith einliest: Hast du ein Client-Zertifikat für den MII Ontoserver, mach mit [Schritt 1b](#schritt-1b) weiter. Ohne Zertifikat überspringst du 1b und machst mit [Schritt 1c](#schritt-1c) weiter, sobald FHIRsmith bereit ist.

### <a id="schritt-1b"></a>💻 Schritt 1b (optional): MII Ontoserver ausprobieren

> ⚠️ **Nur mit Client-Zertifikat:** Der MII Ontoserver lässt dich nur mit einem Client-Zertifikat der SU-TermServ hinein ([mii-termserv.de](https://mii-termserv.de), nur für Personen und Einrichtungen in Deutschland). Hast du keins, überspringe diesen Schritt und mach mit [Schritt 1c](#schritt-1c) weiter.

> ❗ **Nutzungsbedingungen:** Nur für die Entwicklung. Keine Personendaten senden, keine Massenvalidierung (z. B. in ETL-Prozessen).

Im Browser richtest du das Zertifikat nach der [Anleitung der SU-TermServ](https://mii-termserv.de/faq/browser-certificate-setup/) ein. Für `curl` nutzen wir einen Proxy (nginx) aus dem Repository des MII FHIR Validators: Er hängt dein Zertifikat an jede Anfrage an den Ontoserver. Du selbst sprichst den Proxy ohne Zertifikat unter `http://localhost:8083` an.

**1. Repository holen**

```bash
cd ~
git clone https://github.com/medizininformatik-initiative/mii-fhir-validator.git
cd mii-fhir-validator
```

**2. Zertifikat umwandeln**

Dein Zertifikat bekommst du als `.p12`-Datei. Sie enthält zwei Dinge in einer passwortgeschützten Datei: das **Zertifikat** (dein öffentlicher Ausweis) und den **privaten Schlüssel**. Der Proxy braucht beides als getrennte Textdateien im PEM-Format, den Schlüssel ohne Passwort. `openssl` erledigt die Umwandlung und fragt jeweils nach dem Passwort der `.p12`-Datei:

```bash
# Pfad zu deiner .p12-Datei anpassen
# (unter WSL liegt dein Windows-Download-Ordner unter /mnt/c/Users/<Name>/Downloads)
P12=~/mein-zertifikat.p12

# Zertifikat
openssl pkcs12 -in "$P12" -clcerts -nokeys -out nginx/certs/client-cert.pem

# Privater Schlüssel, ohne Passwort
openssl pkcs12 -in "$P12" -nocerts -nodes -out nginx/certs/client-key.key
chmod 600 nginx/certs/client-key.key
```

> ❗ `client-key.key` ist jetzt **ohne Passwort** gespeichert. Wer die Datei hat, kann sich als du beim Ontoserver anmelden. Gib sie nicht weiter und lade sie nirgends hoch.

**3. Proxy starten**

```bash
cp .env.default .env    # Standardeinstellungen des Repositorys, sonst warnt docker compose
sed -i 's/"8081:80"/"127.0.0.1:8083:80"/' docker-compose.yml
docker compose up -d nginx
```

🔍 **Genau hinschauen:**

- `docker compose up -d nginx` startet aus der `docker-compose.yml` des Repositorys **nur den Proxy**. Den Validator dort brauchst du nicht, deinen eigenen startest du in Schritt 2.
- `127.0.0.1:8083`: Port 8081 belegt dein FHIRsmith, der Proxy läuft daher auf **8083**. `127.0.0.1:` macht ihn wie Blaze und den Validator nur auf deinem Rechner erreichbar, denn jede Anfrage über den Proxy läuft mit deinem Zertifikat.

**4. Ausprobieren.** Setze `TX` auf den Proxy, dann funktionieren alle Befehle aus [Übung 5 · Codes prüfen](exercise-5.md) auch am Ontoserver:

```bash
TX=http://localhost:8083/fhir
curl -s "$TX/metadata" | jq '.software.name, .software.version'
```

✅ **Erwartetes Ergebnis** (die Version kann abweichen):

```text
"Ontoserver®"
"6.25.3"
```

Der Proxy kann weiterlaufen, in Schritt 1c vergleichst du den Ontoserver mit deinem eigenen Server. Weiter mit [Schritt 1c](#schritt-1c).

### <a id="schritt-1c"></a>💻 Schritt 1c: Eigenen Terminologieserver prüfen

Warte, bis dein FHIRsmith aus [Schritt 1a](#schritt-1a) bereit ist. Das prüfst du so:

```bash
curl -s http://localhost:8081/fhir/metadata | jq '.software'
# → keine Ausgabe: FHIRsmith liest noch ein, später erneut versuchen
```

✅ **Erwartetes Ergebnis**, sobald der Server bereit ist:

```json
{
  "name": "FHIRsmith",
  "version": "0.16.1",
  "releaseDate": "2026-10-16"
}
```

Setze die Variable `TX` auf deinen eigenen Server und wiederhole die Prüfung der Diagnose `R51`, an der tx.fhir.org gescheitert ist:

```bash
TX=http://localhost:8081/fhir

curl -s -G "$TX/CodeSystem/\$validate-code" \
  --data-urlencode "url=http://fhir.de/CodeSystem/bfarm/icd-10-gm" \
  --data-urlencode "code=R51" \
  | jq -r '.parameter[] | select(.name=="result" or .name=="message" or .name=="display") | "\(.name): \(if has("valueBoolean") then .valueBoolean else .valueString end)"'
```

✅ **Erwartetes Ergebnis:**

```text
result: true
display: Kopfschmerz
```

Dein eigener Server kennt die ICD-10-GM und liefert sogar die deutsche Bezeichnung. tx.fhir.org konnte den Code in Übung 5 gar nicht prüfen.

> 💡 **Vergleichen:** Alle Befehle aus [Übung 5 · Codes prüfen](exercise-5.md) funktionieren auch mit deinem eigenen Server. Prüfe die Codesysteme aus Blaze wie in Übung 5, Schritt 5:
>
> ```bash
> bash ~/tool-kds-sandbox/solution-exercise-5/check_codesystems.sh http://localhost:8081/fhir   # dein FHIRsmith
> bash ~/tool-kds-sandbox/solution-exercise-5/check_codesystems.sh http://localhost:8083/fhir   # MII Ontoserver (nur mit Schritt 1b)
> ```
>
> Welche Codesysteme kennt welcher Server? Vergleiche auch mit tx.fhir.org aus Übung 5. Dein FHIRsmith kennt die deutschen Klassifikationen, aber kein LOINC und SNOMED CT. Der Ontoserver kennt beides. Die übrigen `false`-Zeilen gehen bei allen Servern auf Fehler in den Daten (z. B. `dgkev` statt `dkgev`) oder lokale Hauscodes zurück.

Dein Terminologieserver läuft. Weiter mit [Schritt 2](#schritt-2): Dort legst du den Validator an und verbindest ihn mit diesem Server.

___

## <a id="schritt-2"></a>🛠️ Schritt 2: Validator starten

> ⚠️ **Voraussetzung:** Blaze (Port 8080) läuft, und dein FHIRsmith aus Schritt 1a ist erreichbar. Prüfe das kurz:
>
> ```bash
> # Blaze
> curl -s http://localhost:8080/fhir/metadata | jq '.software'
>
> # Eigener Terminologieserver (FHIRsmith)
> TX=http://localhost:8081/fhir
> curl -s "$TX/metadata" | jq '.software'
> ```

Der Validator läuft wie Blaze und FHIRsmith in einem eigenen Docker-Container. Lege dafür einen eigenen Ordner an:

```bash
mkdir -p ~/validator
cd ~/validator
```

Lege dort die Datei `docker-compose.yml` an. Die Zeile `TX_SERVER` legt fest, welchen Terminologieserver der Validator fragt. Sie zeigt auf deinen FHIRsmith aus Schritt 1a. (Alle `docker-compose.yml` der Übungen findest du auch auf der Seite [Dienste](services.md).)

```yaml
services:
  validator:
    image: "ghcr.io/medizininformatik-initiative/mii-fhir-validator:0.0.1-alpha.9"
    environment:
      # Arbeitsspeicher für den Validator (Standard des Images: 16 GB)
      JAVA_OPTS: "-Xmx4g"
      # Terminologieserver: dein FHIRsmith aus Schritt 1a
      # (Notlösung ohne eigenen Server: "https://tx.fhir.org/r4")
      TX_SERVER: "http://host.docker.internal:8081/fhir"
      # Nur die KDS-Pakete laden, die wir für die Musterdaten brauchen
      IG_PARAMS: >-
        -ig de.basisprofil.r4#1.5.4
        -ig de.medizininformatikinitiative.kerndatensatz.meta#2026.0.0
        -ig de.medizininformatikinitiative.kerndatensatz.base#2026.0.1
        -ig de.medizininformatikinitiative.kerndatensatz.laborbefund#2026.0.3
        -ig de.medizininformatikinitiative.kerndatensatz.diagnose#2025.0.1
    extra_hosts:
      - "host.docker.internal:host-gateway"
    ports:
      - "127.0.0.1:8082:8080"
    volumes:
      - fhir-package-cache:/root/.fhir/packages
      - tx-cache:/tmp/tx-cache

volumes:
  fhir-package-cache:
  tx-cache:
```

🔍 **Genau hinschauen:**

- `ports: "127.0.0.1:8082:8080"`: Im Container lauscht der Validator auf Port 8080. Da Blaze diesen Port auf deinem Rechner schon belegt, machen wir ihn unter **8082** erreichbar. `127.0.0.1:` beschränkt den Zugriff wie bei Blaze auf deinen eigenen Rechner.
- `TX_SERVER`: Die Adresse deines FHIRsmith, hier `host.docker.internal:8081`. Aus Sicht des Containers ist `localhost` der Container selbst, `host.docker.internal` zeigt dagegen auf deinen Rechner. Die Zeile `extra_hosts` macht diesen Namen auch unter Linux bekannt.
- `IG_PARAMS`: Welche Implementation Guides der Validator lädt. Lässt du die Variable weg, lädt er alle 17 MII-Module. Das braucht aber deutlich mehr Arbeitsspeicher und Startzeit.

Starte den Validator und verfolge den Start im Log:

```bash
docker compose up -d
docker compose logs -f validator
```

Beim ersten Start kopiert der Container zuerst die mitgelieferten FHIR-Pakete in seinen Cache. Das dauert einige Minuten, und das Log bleibt so lange **leer**. Danach lädt der Validator die Pakete und baut seine Profile auf. Insgesamt dauert der erste Start etwa **5 Minuten**. Der Validator ist bereit, wenn diese Zeile erscheint:

```text
FHIR Validator HTTP Service started on  0.0.0.0/0.0.0.0:8080
```

Mit `Strg+C` beendest du die Log-Anzeige; der Validator läuft weiter.

> 🔍 **Genau hinschauen:** Im Log steht, mit welchem Terminologieserver sich der Validator verbunden hat (`Terminology server …`) und welche Pakete er geladen hat (`Package Summary`). Findest du die fünf Pakete aus `IG_PARAMS`?

Prüfe, ob der Validator antwortet, indem du eine minimale Patient-Ressource validierst:

```bash
echo '{"resourceType": "Patient"}' \
  | curl -s -X POST http://localhost:8082/validateResource \
      -H "Content-Type: application/fhir+json" \
      --data @- \
  | jq
```

✅ **Erwartetes Ergebnis:** Ein `OperationOutcome` mit genau einem `issue`, einer **Warnung**:

```text
"severity": "warning",
"code": "invariant",
"details": { "text": "Constraint failed: dom-6: 'A resource should have narrative for robust management' ... (Best Practice Recommendation)" }
```

Der Validator antwortet also und prüft. Die Warnung ist nur eine Empfehlung: Eine Ressource sollte einen lesbaren Text (`text`, Narrative) mitbringen. Fehler (`error`) gibt es keine, denn ein leerer Patient ist nach dem FHIR-Basisstandard gültig.

> 💡 `--data @-` liest die Ressource aus der Pipe statt aus einer Datei. So kannst du Ressourcen direkt aus Blaze an den Validator weiterreichen.

___

## <a id="schritt-3"></a>💻 Schritt 3: Eigene Ressource validieren

Deine HbA1c-Observation aus [Übung 1 · Profil erstellen](exercise-1.md) liegt seit [Übung 2 · FHIR-Server starten](exercise-2.md) in Blaze. Hole sie dir als Datei:

```bash
cd ~/validator
curl -s http://localhost:8080/fhir/Observation/Example-Studie-HbA1c-01 > hba1c.json
jq '.meta.profile' hba1c.json
```

Die Ressource gibt in `meta.profile` dein eigenes Studienprofil an (`http://example.org/StructureDefinition/pr-studie-hba1c`).

### 3.1 Validieren wie angegeben

Ohne weitere Angaben prüft der Validator gegen die Profile aus `meta.profile`. Seine Antwort ist ein `OperationOutcome` wie beim Test in Schritt 2. `jq` gibt daraus jede Meldung als kleinen Block aus: in der ersten Zeile Schwere und Stelle in der Ressource, darunter der Text:

```bash
curl -s -X POST http://localhost:8082/validateResource \
  -H "Content-Type: application/fhir+json" \
  --data @hba1c.json \
  | jq -r '.issue[] | "\(.severity) – \(.expression[0])\n  \(.details.text)\n"'
```

🔍 **Genau hinschauen:** Was meldet der Validator zu deinem Studienprofil? Kennt er es überhaupt?

✅ **Erwartetes Ergebnis:** 2 Fehler und 9 Warnungen. Sortiert nach Ursache:

| Schwere | Meldung (gekürzt) | Ursache |
| --- | --- | --- |
| `warning` | `Profile reference 'http://example.org/…/pr-studie-hba1c' has not been checked because it could not be found` | Der Validator kennt dein Studienprofil nicht und prüft **nicht** dagegen |
| `error` | `Example URLs are not allowed in this context` (2×: Profil-URL und `identifier.system`) | `example.org` und `acme.com` sind Platzhalter-Adressen, in echten Daten nicht erlaubt |
| `warning` | `A definition for CodeSystem 'http://loinc.org' … could not be found` (2×) | Dein Terminologieserver hat kein LOINC (siehe Schritt 1) |
| `warning` | `A definition for CodeSystem 'http://snomed.info/sct' … could not be found` (3×, mit `Error begin -1 …`) | Dein Terminologieserver hat kein SNOMED CT |
| `warning` | `None of the codings provided are in the value set 'IdentifierType'` | `OBI` verlangt der KDS, das allgemeine FHIR-ValueSet kennt es nicht. Kein Problem |
| `warning` | `dom-6: A resource should have narrative`, `all observations should have a performer` | Best-Practice-Empfehlungen |

Die Warnungen zu LOINC und SNOMED CT heißen: **nicht geprüft**, nicht falsch. Mit einem Terminologieserver, der beide kennt (z. B. dem MII Ontoserver), fallen sie weg.

### 3.2 Gegen das MII-Laborprofil validieren

Dein Studienprofil erbt von `MII_PR_Labor_Laboruntersuchung`. Dieses Profil kennt der Validator. Mit dem Parameter `profile` gibst du es beim Aufruf vor:

```bash
curl -s -X POST "http://localhost:8082/validateResource?profile=https://www.medizininformatik-initiative.de/fhir/core/modul-labor/StructureDefinition/ObservationLab" \
  -H "Content-Type: application/fhir+json" \
  --data @hba1c.json \
  | jq -r '.issue[] | "\(.severity) – \(.expression[0])\n  \(.details.text)\n"'
```

✅ **Erwartetes Ergebnis:** Wieder 2 Fehler und 9 Warnungen, fast dieselben wie in 3.1. Zwei Meldungen sind anders:

| | Meldung | Warum |
| --- | --- | --- |
| entfällt | `None of the codings provided are in the value set 'IdentifierType'` | Das MII-Profil erlaubt `OBI` über ein eigenes ValueSet |
| neu | `ValueSet 'http://hl7.org/fhir/uv/ips/ValueSet/results-laboratory-observations-uv-ips' not found` | Das MII-Profil verweist für `code` auf ein ValueSet, das der Validator nicht geladen hat. Nur eine Empfehlung (`preferred`), daher eine Warnung |

Gegen das MII-Profil gibt es also **keine strukturellen Fehler**: Pflichtfelder, Kategorien, Einheit und Bezugsdatum passen. Übrig bleiben die Platzhalter-URLs aus dem Beispiel und Codes, die dein Terminologieserver nicht prüfen kann.

> 💡 Neuere Versionen des Validators nennen die Parameter `profiles` und `displayOption` statt `profile` und `checkDisplay`. Meldet er `Unable to process param`, probiere die andere Schreibweise.

> 💡 **Eigene Profile laden:** Damit der Validator dein Studienprofil selbst kennt, bräuchte er das Paket deines IG. Der IG Publisher erzeugt es in [Übung 1 · Profil erstellen](exercise-1.md) als `output/package.tgz`. Über `IG_PARAMS` (z. B. `-ig /igs/package.tgz`) und einen eingebundenen Ordner `/igs` kann der Validator es laden. Für diese Übung reicht die Prüfung gegen das MII-Profil.

___

## <a id="schritt-4"></a>💻 Schritt 4: Musterdaten aus Blaze validieren

Jetzt prüfst du echte KDS-Daten aller drei Standorte aus [Übung 3 · Musterdaten laden](exercise-3.md). In [Übung 4 · Daten abfragen](exercise-4.md) sind dir dabei schon Auffälligkeiten begegnet. Was sagt der Validator dazu?

### 4.1 Der seltsame Diagnosecode

```bash
curl -s "http://localhost:8080/fhir/Condition?code=570762" | jq '.entry[0].resource' > condition-570762.json

curl -s -X POST http://localhost:8082/validateResource \
  -H "Content-Type: application/fhir+json" \
  --data @condition-570762.json \
  | jq -r '.issue[] | "\(.severity) – \(.expression[0])\n  \(.details.text)\n"'
```

✅ **Erwartetes Ergebnis:** 2 Fehler und 2 Warnungen:

| Schwere | Meldung (gekürzt) | Bedeutung |
| --- | --- | --- |
| `error` | `Unknown code '570762' in the CodeSystem '…/icd-10-gm' version '2025'` | Den Code gibt es in der ICD-10-GM nicht |
| `error` | `The code provided … was not found in the value set 'MII VS Diagnose ICD-10-GM' … a code from this value set is required` | Das KDS-Profil verlangt einen Code aus diesem ValueSet (Bindung `required`) |
| `warning` | `Constraint failed: icd-regex: 'In code sind nur gültige ICD-10-Codes ohne Zusätze erlaubt'` | Der Code hat nicht einmal das Format eines ICD-10-Codes |
| `warning` | `dom-6: A resource should have narrative` | Best-Practice-Empfehlung |

Hier findet der Validator einen **echten Datenfehler**: Der Code ist kein ICD-10-GM-Code.

### 4.2 Eine gültige Diagnose zum Vergleich

Hole eine Diagnose mit dem gültigen Code `R51` (Kopfschmerz). Die Abfrage wählt eine aus, die eine ältere Profilversion nennt. Warum das wichtig ist, siehst du gleich.

```bash
curl -s -G "http://localhost:8080/fhir/Condition" \
  --data-urlencode "code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|R51" \
  --data-urlencode "_profile=https://www.medizininformatik-initiative.de/fhir/core/modul-diagnose/StructureDefinition/Diagnose|2024.0.0" \
  | jq '.entry[0].resource' > condition-r51.json

curl -s -X POST http://localhost:8082/validateResource \
  -H "Content-Type: application/fhir+json" \
  --data @condition-r51.json \
  | jq -r '.issue[] | "\(.severity) – \(.expression[0])\n  \(.details.text)\n"'
```

✅ **Erwartetes Ergebnis:** Kein Fehler, aber auch keine echte Prüfung:

| Schwere | Meldung (gekürzt) |
| --- | --- |
| `information` | `A definition could not be found for Canonical URL '…/StructureDefinition/Diagnose\|2024.0.0'` |
| `warning` | `Profile reference '…/Diagnose\|2024.0.0' has not been checked because it could not be found …` |
| `warning` | `dom-6: A resource should have narrative` |

🔍 **Genau hinschauen:** Vergleiche `meta.profile` der beiden Diagnosen mit dem Diagnose-Paket in `IG_PARAMS` (`#2025.0.1`):

```bash
jq '.meta.profile' condition-570762.json condition-r51.json
```

Die Diagnose aus 4.1 nennt `Diagnose|2025.0.0`. Der Validator hat das Profil aus dem geladenen Paket 2025.0.1 verwendet und gegen das KDS-Profil geprüft. Die Diagnose aus 4.2 nennt `Diagnose|2024.0.0`. Diese Version kennt der Validator nicht. Er prüft dann **nur gegen den FHIR-Basisstandard** und sagt das lediglich als `information` und `warning`.

> ❗ **Merke:** „Keine Fehler" heißt nicht automatisch „gültig nach KDS". Prüfe immer, ob der Validator das Profil überhaupt gefunden hat. Mit dem Parameter `profile` aus Schritt 3.2 kannst du die Prüfung gegen ein bestimmtes Profil erzwingen.

### 4.3 Anzeigetexte mitprüfen

Ein Code kann neben `code` auch einen Anzeigetext (`display`) tragen. Standardmäßig prüft der Validator nicht, ob dieser Text zum Code passt. Mit dem Parameter `checkDisplay=Check` fragt er dafür mit `$validate-code` beim Terminologieserver nach, so wie du es in [Übung 5 · Codes prüfen](exercise-5.md) von Hand gemacht hast.

Die Diagnosen aus den Musterdaten haben keinen Anzeigetext. Wir nehmen deshalb eine Prozedur mit OPS-Code:

```bash
curl -s "http://localhost:8080/fhir/Procedure?code=http://fhir.de/CodeSystem/bfarm/ops|1-63a&_count=1" \
  | jq '.entry[0].resource' > procedure-ops.json

jq '.code.coding[] | {system, version, code, display}' procedure-ops.json
```

✅ **Erwartetes Ergebnis:** OPS-Code `1-63a` in der Version `2017` mit dem Anzeigetext „Kapselendoskopie des Dünndarms“.

Validiere die Prozedur mit Prüfung der Anzeigetexte:

```bash
curl -s -X POST "http://localhost:8082/validateResource?checkDisplay=Check" \
  -H "Content-Type: application/fhir+json" --data @procedure-ops.json \
  | jq -r '.issue[] | "\(.severity) – \(.expression[0])\n  \(.details.text)\n"'
```

✅ **Erwartetes Ergebnis:** 4 Meldungen, keine davon zum Anzeigetext: Der Anzeigetext stimmt. Auch das ist ein Ergebnis. Stünde im `display` ein falscher Text, käme eine Meldung dazu. Die übrigen Meldungen kennst du schon: Das Prozedurprofil ist nicht in `IG_PARAMS` geladen (wie in 4.2), SNOMED CT kennt dein Terminologieserver nicht, dazu `dom-6`.

Zur Kontrolle fragst du den Terminologieserver selbst, wie in Übung 5:

```bash
TX=http://localhost:8081/fhir
curl -s -G "$TX/CodeSystem/\$validate-code" \
  --data-urlencode "url=http://fhir.de/CodeSystem/bfarm/ops" \
  --data-urlencode "version=2017" \
  --data-urlencode "code=1-63a" \
  --data-urlencode "display=Kapselendoskopie des Dünndarms" \
  | jq -r '.parameter[] | select(.name=="result" or .name=="message" or .name=="display") | "\(.name): \(.valueBoolean // .valueString)"'
```

✅ **Erwartetes Ergebnis:** `result: true`

### 4.4 Wie gut sind die Diagnosen der Musterdaten?

In 4.2 hast du gesehen: Nennt eine Diagnose eine Profilversion, die der Validator nicht kennt, prüft er sie nur gegen den FHIR-Basisstandard. Wie viele Diagnosen betrifft das, und was zeigt sich, wenn du sie gegen das aktuelle KDS-Profil prüfst?

**1. Welche Profilversionen nennen die Diagnosen?** `sort | uniq -c` zählt, wie oft jede Zeile vorkommt:

```bash
curl -s "http://localhost:8080/fhir/Condition?_count=4000" \
  | jq -r '.entry[].resource.meta.profile[]' | sort | uniq -c
```

✅ **Erwartetes Ergebnis:**

```text
     57 https://www.medizininformatik-initiative.de/fhir/core/modul-diagnose/StructureDefinition/Diagnose|2024.0.0
    425 https://www.medizininformatik-initiative.de/fhir/core/modul-diagnose/StructureDefinition/Diagnose|2025.0.0
```

**2. Die 57 Diagnosen mit `|2024.0.0` gegen das aktuelle Profil prüfen.** Erst holst du ihre IDs, dann validiert die Schleife jede mit `profile` und speichert den Bericht als Datei:

```bash
cd ~/validator
mkdir -p diagnosen
DIAGNOSE=https://www.medizininformatik-initiative.de/fhir/core/modul-diagnose/StructureDefinition/Diagnose

curl -s -G "http://localhost:8080/fhir/Condition" \
  --data-urlencode "_profile=$DIAGNOSE|2024.0.0" \
  --data-urlencode "_count=100" \
  | jq -r '.entry[].resource.id' > diagnosen/ids.txt

for id in $(cat diagnosen/ids.txt); do
  curl -s "http://localhost:8080/fhir/Condition/$id" > diagnosen/$id.json
  curl -s -X POST "http://localhost:8082/validateResource?profile=$DIAGNOSE" \
    -H "Content-Type: application/fhir+json" --data @diagnosen/$id.json > diagnosen/bericht-$id.json
done
```

**3. Welche Berichte enthalten Fehler?** `grep -l` listet die Dateien, in denen `"error"` vorkommt:

```bash
grep -l '"error"' diagnosen/bericht-*.json
```

✅ **Erwartetes Ergebnis:**

```text
diagnosen/bericht-Diagnosis-010.json
diagnosen/bericht-Diagnosis-026.json
```

Sieh dir für eine dieser Diagnosen den Code und die Fehlermeldungen an:

```bash
jq '.code.coding' diagnosen/Diagnosis-010.json
jq -r '.issue[] | select(.severity == "error") | "\(.severity) – \(.expression[0])\n  \(.details.text)\n"' diagnosen/bericht-Diagnosis-010.json
```

✅ **Erwartetes Ergebnis** (die zweite Fehlermeldung ist sehr lang, hier gekürzt):

```text
[
  {
    "system": "http://fhir.de/CodeSystem/bfarm/icd-10-gm",
    "version": "2021",
    "code": "Z11 U99.0!"
  }
]
error – Condition.code.coding[0].code
  Unknown code 'Z11 U99.0!' in the CodeSystem 'http://fhir.de/CodeSystem/bfarm/icd-10-gm' version '2021'

error – Condition.code.coding[0]
  The code provided (http://fhir.de/CodeSystem/bfarm/icd-10-gm#Z11 U99.0!) was not found in the value set 'MII VS Diagnose ICD-10-GM' (…), and a code from this value set is required: …
```

Den Code gibt es nicht, und er gehört nicht zum ICD-10-GM-ValueSet, das das KDS-Profil zwingend verlangt.

🧩 **Was du gerade gesehen hast:**

- 57 der 482 Diagnosen nennen eine Profilversion, die der Validator nicht kennt. Ohne `profile` hätte er sie nur gegen den FHIR-Basisstandard geprüft.
- Mit `profile` erfüllen 55 davon auch das aktuelle KDS-Profil. Die alte Versionsangabe ist bei ihnen nur eine Formsache.
- Zwei Diagnosen fallen durch. Sie tragen den Code `Z11 U99.0!`. Einzeln sind beide gültige ICD-10-GM-Codes, zusammen kodieren sie einen negativen SARS-CoV-2-Test. In einem `Coding` darf aber nur **ein** Code stehen. Das ist also ein Fehler in der Abbildung, nicht in der Diagnose. Den unbekannten Code hätte der Validator auch ohne `profile` gemeldet, denn Codes prüft er immer am Terminologieserver. Dass das KDS-Profil hier zwingend einen Code aus dem ICD-10-GM-ValueSet verlangt, siehst du erst mit `profile`.

Bei einer unbekannten Profilversion entfallen also alle Regeln des Profils, z. B. Bindungen und Pflichtfelder. Ob Daten den KDS wirklich erfüllen, zeigt erst die Prüfung mit `profile`.

> ⚠️ **Ganze Bundles:** Der Validator kann auch ein komplettes Bundle prüfen. Bei den rund 8.000 Ressourcen aus [Übung 3 · Musterdaten laden](exercise-3.md) dauert das aber sehr lange und braucht viel Speicher. Im DIZ-Alltag validiert man deshalb meist Stichproben oder einzelne Ressourcen direkt in der ETL-Strecke.

Die Berichte aus diesem Schritt wertest du in [Übung 7 · Berichte auswerten](exercise-7.md) genauer aus. Lass die Dateien `hba1c.json`, `condition-570762.json` und `condition-r51.json` im Ordner `~/validator` liegen.

___

## <a id="vertiefung"></a>🔍 Vertiefung: Kommandozeile und Ausbau des Terminologieservers

### Validator über die Kommandozeile

Der MII FHIR Validator startet intern den HL7-Validator (`validator_cli.jar`) im Server-Modus. Denselben Validator kannst du auch direkt per Kommandozeile aufrufen, z. B. in einer CI-Pipeline. Java hast du seit [Übung 1 · Profil erstellen](exercise-1.md) installiert. Die wichtigsten Parameter:

| Parameter | Bedeutung | Entspricht im MII FHIR Validator |
| --- | --- | --- |
| `-version 4.0.1` | FHIR-Version (R4) | `FHIR_VERSION` |
| `-ig <paket>#<version>` | Implementation Guide laden | `IG_PARAMS` |
| `-tx <url>` | Terminologieserver | `TX_SERVER` |
| `-profile <url>` | Gegen dieses Profil prüfen | Query-Parameter `profile` |

Der Rückgabewert (Exit-Code) des Aufrufs zeigt, ob die Validierung erfolgreich war:

| Exit-Code | Bedeutung |
| --- | --- |
| `0` | Keine Fehler oder Warnungen |
| `1` | Nur Warnungen |
| `2+` | Fehler |

### LOINC, SNOMED CT und HTTPS im eigenen Terminologieserver

- **LOINC** erfordert einen kostenlosen Account bei [loinc.org](https://loinc.org/signup). FHIRsmith liest LOINC nicht direkt, sondern aus einer selbst erzeugten Datenbankdatei (`loinc_<version>.db`). Der FHIRsmith-Importer erstellt sie aus dem LOINC-Download; das dauert mehrere Stunden, ist aber nur einmal nötig. Eingebunden wird sie in der `library.yml` mit `- loinc:loinc_2.83.db`.
- **SNOMED CT** ist lizenzpflichtig; in Deutschland vergibt das [BfArM](https://www.bfarm.de/DE/Kodiersysteme/Terminologien/SNOMED-CT/_node.html) kostenfreie Lizenzen. Auch hier erzeugt der Importer zunächst eine Cache-Datei (`- snomed:sct_ger_<datum>.cache`); das dauert ebenfalls Stunden. Lizenzpflichtige Inhalte wie die SNOMED-CT-Releasedateien gehören nie in ein Git-Repository oder ein Docker-Image.
- **HTTPS:** Der IG Publisher akzeptiert Terminologieserver nur über HTTPS und lokale Adressen nur nach expliziter Freigabe in der `fhir-settings.json`. Dafür setzt man einen Reverse Proxy (z. B. nginx mit selbstsigniertem Zertifikat) vor FHIRsmith.

> 💡 Der [IG Publisher](exercise-1.md) aus Übung 1 nutzt intern ebenfalls diesen Validator. Seinen QA-Report kannst du deshalb mit dem Wissen aus [Übung 7 · Berichte auswerten](exercise-7.md) genauso lesen.

___

## <a id="zusammenfassung"></a>🏁 Zusammenfassung und Ausblick

**Was du mitnehmen sollst:**

- Ein Validator prüft Ressourcen gegen **Profile**. Welche Profile er kennt, bestimmen die geladenen IG-Pakete.
- Für kleine Tests reicht der zentrale **MII Ontoserver**. Für die eigene Validierung, z. B. in der ETL-Strecke, betreibt man einen **eigenen Terminologieserver**.
- Alle Code-Prüfungen gibt der Validator an **einen Terminologieserver** weiter. Was dort nicht geladen ist, kann er nicht prüfen – die Wahl des Terminologieservers bestimmt also, was die Validierung aussagt.
- Profile haben **Versionen**. Nennt eine Ressource eine Profilversion, die der Validator nicht kennt, prüft er nur gegen den FHIR-Basisstandard. „Keine Fehler“ heißt dann nicht „gültig nach KDS“. Mit dem Parameter `profile` erzwingst du die Prüfung gegen ein bestimmtes Profil.

**Ausblick:**

- [Übung 7 · Berichte auswerten](exercise-7.md): Validierungsberichte lesen, filtern und Meldungen einordnen

___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • **6 · Ressourcen validieren** • [7 · Berichte auswerten](exercise-7.md)
___
___
