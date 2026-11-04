___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • **6 · Ressourcen validieren** • [7 · Berichte auswerten](exercise-7.md)
___
___

# 🟣 Nutzen eines FHIR Validators

**Nächste Schritte:**

- Stelle einen Terminologieserver mit deutschen Klassifikationen bereit: einen **eigenen FHIRsmith** oder den **MII Ontoserver**
- Starte den **MII FHIR Validator** per Docker Compose und verbinde ihn mit diesem Terminologieserver
- Validiere deine HbA1c-Observation aus [Übung 1 · Profil erstellen](exercise-1.md) gegen das MII-Laborprofil
- Validiere einzelne Musterdaten aus Blaze, darunter die Auffälligkeiten aus [Übung 4 · Daten abfragen](exercise-4.md)

In [Übung 5 · Codes prüfen](exercise-5.md) hast du einzelne Codes am öffentlichen Terminologieserver tx.fhir.org geprüft – und gesehen, dass er ICD-10-GM, OPS und die Codesysteme der MII nicht kennt. Jetzt prüfst du **ganze Ressourcen** gegen die Profile des Kerndatensatzes. Dafür braucht der Validator einen Terminologieserver, der auch die deutschen Inhalte kennt.

Ob eine FHIR-Ressource formal in Ordnung ist, lässt sich schnell und ohne Installation prüfen: Webtools wie fhirtoolbox.com laufen im Browser, finden Tippfehler, falsche Datentypen oder fehlende Pflichtfelder und liefern sofort Rückmeldung. Auch SUSHI weist beim Build auf Fehler im FSH-Quelltext hin, etwa auf Syntaxfehler oder unbekannte Elementpfade. Das reicht aber nur für die Struktur. Ob ein Code wirklich existiert, zum vorgeschriebenen ValueSet gehört und ein passendes Display hat, oder ob die Ressource das richtige Profil erfüllt, kann ein solches Tool nicht beurteilen. Dafür braucht es einen **Validator**, der die Profile kennt, und einen **Terminologieserver**, der die Codes prüft. Erst diese Kombination zeigt, ob eine Ressource nicht nur „gut aussieht“, sondern den Vorgaben des Kerndatensatzes entspricht.

> 💡 **Ausblick:** In [Übung 7 · Berichte auswerten](exercise-7.md) lernst du, die Validierungsberichte aus dieser Übung **zu interpretieren** und einzuordnen.

___

📋 **Übersicht:**

- [Hintergrund: Was prüft ein Validator?](#hintergrund)
- [Aufbau: Drei Server, drei Ports](#aufbau)
- [Schritt 1: Terminologieserver bereitstellen](#schritt-1)
- [Schritt 2: Validator starten](#schritt-2)
- [Schritt 3: Eigene Ressource validieren](#schritt-3)
- [Schritt 4: Musterdaten aus Blaze validieren](#schritt-4)
- [Vertiefung: Kommandozeile und Ausbau des Terminologieservers](#vertiefung)
- [Zusammenfassung und Ausblick](#zusammenfassung)

___

## <a id="hintergrund"></a>📖 Hintergrund: Was prüft ein Validator?

### Strukturelle Validierung vs. Conformance-Validierung

| Prüfebene | Strukturell (z. B. fhirtoolbox.com) | Conformance (HL7 Validator, IG Publisher, MII FHIR Validator) |
|---|---|---|
| **Frage** | Ist das gültiges FHIR-JSON? | Entspricht die Ressource dem Standard und den Profilen? |
| **Syntax / Datentypen** | ✅ | ✅ |
| **Pflichtelemente / Kardinalität** | Teilweise (nur ausgewählte Ressourcen) | ✅ Alle Elemente laut Profil |
| **Invarianten (FHIRPath)** | ❌ | ✅ |
| **Profile / IGs / Slicing** | ❌ | ✅ |
| **Codes in fest eingebauten Listen** (z. B. `gender`) | ✅ | ✅ |
| **Code existiert im CodeSystem?** | ❌ | ✅ via Terminologieserver (`$validate-code`) |
| **Code gehört zum gebundenen ValueSet?** | ❌ | ✅ via Terminologieserver |
| **Display passt zum Code?** | ❌ | ✅ via Terminologieserver (optional) |
| **Terminologieserver nötig?** | Nein | Ja |
| **Typischer Einsatz** | Schneller Check beim Schreiben | Vor Release, in CI, in der ETL-Strecke |

> ⚠️ **Grenzen:** Ein Validator prüft **nicht**, ob Inhalte fachlich plausibel sind (z. B. ein Laborwert von 300 g/dL Hämoglobin) oder ob Code und Einheit fachlich zusammenpassen. Ob referenzierte Ressourcen (z. B. `Patient/...`) tatsächlich existieren, prüft er bei einer einzelnen Ressource ebenfalls nicht. Das hat in [Übung 3 · Musterdaten laden](exercise-3.md) Blaze beim Upload übernommen.

### Welcher Validator für welchen Zweck?

Es gibt nicht *den einen* FHIR-Validator. Die meisten Werkzeuge nutzen im Kern denselben HL7-Validator (`validator_cli.jar`) und unterscheiden sich darin, wie man sie aufruft und wie sie vorkonfiguriert sind:

| Werkzeug | Aufruf | Typischer Einsatz | Kennst du aus |
| --- | --- | --- | --- |
| `$validate-code` am Terminologieserver | REST-Anfrage | Einzelnen Code prüfen | [Übung 5 · Codes prüfen](exercise-5.md) |
| IG Publisher | Build-Prozess | Profile und Beispiele eines eigenen IG prüfen (QA-Report) | [Übung 1 · Profil erstellen](exercise-1.md) |
| HL7 Validator (`validator_cli.jar`) | Kommandozeile | Beliebige Ressourcen gegen beliebige IGs, z. B. in CI | [Vertiefung](#vertiefung) |
| **MII FHIR Validator** | HTTP: `POST /validateResource` | **Ressourcen gegen die MII-KDS-Profile prüfen** | **diese Übung** |

Im MII-Kontext nutzen wir den [MII FHIR Validator](https://github.com/medizininformatik-initiative/mii-fhir-validator): Er ist der HL7-Validator im Server-Modus, als Docker-Image fertig vorkonfiguriert mit den Paketen der MII-Kerndatensatz-Module. Daneben gibt es z. B. den Validator von Firely (.NET; das Firely Terminal kennst du aus [Übung 1 · Profil erstellen](exercise-1.md)) und den gematik Referenzvalidator für Anwendungen der Telematikinfrastruktur. Validatoren auf derselben Basis (HL7-Validator) liefern bei gleicher Konfiguration dieselben Ergebnisse – Unterschiede entstehen vor allem durch geladene Pakete, Versionen und den Terminologieserver.

___

## <a id="aufbau"></a>🧩 Aufbau: Drei Server, drei Ports

In dieser Übung arbeiten drei Server zusammen:

```text
                     Ressource (JSON)                    $validate-code, $expand
  curl  ─────────────────────────────────▶  Validator  ─────────────────────────▶  Terminologieserver
   ▲                                       :8082                                   (FHIRsmith :8081
   │                                                                                oder MII Ontoserver)
   │ GET Ressource
   │
 Blaze :8080  (Musterdaten aus Übung 3)
```

| Server | Port | Aus Übung | Aufgabe |
| --- | --- | --- | --- |
| Blaze | `8080` | [Übung 2 · FHIR-Server starten](exercise-2.md) | FHIR-Server mit den Musterdaten |
| Terminologieserver | `8081` (eigener FHIRsmith) oder extern (MII Ontoserver) | diese Übung, Schritt 1 | Kennt die Codesysteme, z. B. ICD-10-GM, OPS, UCUM |
| MII FHIR Validator | `8082` | diese Übung, Schritt 2 | Prüft Ressourcen gegen Profile, fragt Codes beim Terminologieserver an |

> 💡 **Eigenes Setup mit anderen Adressen?** Laufen einzelne Server bei dir nicht lokal (z. B. auf einem Server im Netz), ersetze `localhost` in den Befehlen durch dessen Adresse und setze `TX_SERVER` in Schritt 2 auf die URL deines Terminologieservers.

___

## <a id="schritt-1"></a>🛠️ Schritt 1: Terminologieserver bereitstellen

Der Validator gibt jede Code-Prüfung an **einen** Terminologieserver weiter. Wähle eine der folgenden Möglichkeiten:

| | A: Eigener FHIRsmith (empfohlen) | B: MII Ontoserver | C: tx.fhir.org |
| --- | --- | --- | --- |
| **Adresse** | `http://localhost:8081/fhir` | [`https://ontoserver.mii-termserv.de/fhir`](https://ontoserver.mii-termserv.de/fhir) | `https://tx.fhir.org/r4` |
| **Inhalt** | ICD-10-GM, OPS, Alpha-ID-SE, UCUM, HL7-Codesysteme, ValueSets der KDS-Basis; **ohne** LOINC und SNOMED CT | Die Terminologien der MII-Profile, betrieben von der SU-TermServ | Internationale Terminologien; **ohne** deutsche Klassifikationen |
| **Aufwand** | Pakete herunterladen, Konfiguration anlegen, Start ca. 15 Minuten | Zugang beantragen, Client-Zertifikat einrichten | Keiner |
| **Voraussetzung** | Docker, bis 4 GB Arbeitsspeicher | Client-Zertifikat (nur Personen und Einrichtungen in Deutschland) | Internetzugang |
| **Einschränkung** | LOINC- und SNOMED-Codes können nicht geprüft werden | Nur für Entwicklung, keine Personendaten, keine Massenvalidierung | Diagnosen und Prozeduren können nicht geprüft werden |
| **Weiter mit** | [Schritt 1a](#schritt-1a) | [Schritt 1b](#schritt-1b) | [Schritt 2](#schritt-2): Dort legst du den Validator an und stellst ihn auf tx.fhir.org ein |

> 💡 **Warum LOINC und SNOMED CT nicht im eigenen Server?** Beide lassen sich in FHIRsmith laden, ein Importer muss sie aber erst in eine Datenbankdatei umwandeln. Das dauert jeweils mehrere Stunden. Für die Übung verzichten wir darauf; im DIZ macht man das einmalig pro Version. Mehr dazu in der [Vertiefung](#vertiefung).

### <a id="schritt-1a"></a>💻 Schritt 1a: Eigener Terminologieserver mit FHIRsmith

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

**3. Server starten.** Lege im Ordner `~/terminology-server` die Datei `docker-compose.yml` an:

> 💡 Alle Dienste der Übungen mit Ports und `docker-compose.yml` findest du gesammelt auf der Seite [Dienste](services.md).

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

> 💡 Blaze aus [Übung 2 · FHIR-Server starten](exercise-2.md) belegt Port 8080, der Terminologieserver läuft daher auf **Port 8081**. `NODE_OPTIONS` erlaubt dem Server, bis zu 4 GB Arbeitsspeicher zu nutzen.

```bash
cd ~/terminology-server
docker compose up -d
docker compose logs -f tx
```

Beim Start lädt FHIRsmith die `npm:`-Pakete herunter und liest alle Terminologien ein. Das dauert etwa **15 Minuten**, den größten Teil davon braucht das Paket `hl7.terminology.r4`. Der Server ist bereit, wenn diese Zeile erscheint:


```text
=== Server running on http://localhost:3000 ===
```

`localhost:3000` ist die Adresse im Container. Von deinem Rechner aus erreichst du den Server unter `http://localhost:8081`. Mit `Strg+C` beendest du die Log-Anzeige; der Server läuft weiter.

> 🔍 **Genau hinschauen:** Weiter oben im Log listet FHIRsmith jede geladene Quelle mit der Anzahl ihrer CodeSystems und ValueSets auf. Findest du ICD-10-GM, OPS und Alpha-ID-SE?

**4. Prüfen.** Setze die Variable `TX` aus [Übung 5 · Codes prüfen](exercise-5.md) auf deinen eigenen Server und wiederhole die Prüfung der Diagnose `R51`, an der tx.fhir.org gescheitert ist:

```bash
TX=http://localhost:8081/fhir

curl -s -G "$TX/CodeSystem/\$validate-code" \
  --data-urlencode "url=http://fhir.de/CodeSystem/bfarm/icd-10-gm" \
  --data-urlencode "code=R51" \
  | jq -r '.parameter[] | select(.name=="result" or .name=="message" or .name=="display") | "\(.name): \(if has("valueBoolean") then .valueBoolean else .valueString end)"'
```

✅ **Erwartetes Ergebnis:** `result: true` und als `display` die deutsche Bezeichnung „Kopfschmerz“.

<!-- TODO beim Test: genaue Ausgabe eintragen -->

> 💡 **Ausprobieren:** Alle Befehle aus [Übung 5 · Codes prüfen](exercise-5.md) funktionieren jetzt auch mit deinem eigenen Server. Lass die Schleife aus Übung 5, Schritt 5 noch einmal laufen: Welche Codesysteme kennt dein Server, welche tx.fhir.org?

Dein Terminologieserver läuft. Weiter mit [Schritt 2](#schritt-2): Dort legst du den Validator an und verbindest ihn mit diesem Server.

### <a id="schritt-1b"></a>💻 Schritt 1b: MII Ontoserver

Die SU-TermServ der MII betreibt den Ontoserver unter [`https://ontoserver.mii-termserv.de/fhir`](https://ontoserver.mii-termserv.de/fhir). Ohne Client-Zertifikat lässt er dich nicht hinein.

**Zertifikat besorgen:** Zugang bei der SU-TermServ beantragen ([mii-termserv.de](https://mii-termserv.de), nur für Personen und Einrichtungen in Deutschland).

Mit dem Zertifikat gibt es zwei Wege zum Server:

| | Im Browser | Für den Validator |
| --- | --- | --- |
| **Wozu** | Server ansehen, Codes nachschlagen | Ressourcen automatisch prüfen |
| **Wo liegt das Zertifikat** | Als `.p12` importiert. Windows: zentral im Windows-Zertifikatspeicher (Chrome/Edge). Linux: kein zentraler Speicher, Chrome-Browser teilen sich `~/.pki/nssdb`. Firefox: immer eigener Speicher | Als Dateien `client-cert.pem` und `client-key.key` (Schlüssel **entschlüsselt**) |
| **Einrichtung** | [Anleitung der SU-TermServ](https://mii-termserv.de/faq/browser-certificate-setup/) | Die Befehle unten |

> ❗ **Nutzungsbedingungen:** Nur für die Entwicklung. Keine Personendaten senden, keine Massenvalidierung (z. B. in ETL-Prozessen).

Für den Validator nutzen wir eine fertige Konfiguration aus dem Repository des MII FHIR Validators. Ein Proxy (nginx) schickt jede Anfrage mit deinem Zertifikat an den Ontoserver. Der Validator spricht nur mit dem Proxy und braucht selbst kein Zertifikat. Ports: Validator `8082`, Proxy `8083`.

```bash
cd ~
git clone https://github.com/medizininformatik-initiative/mii-fhir-validator.git
cd mii-fhir-validator

# Zertifikat und Schlüssel ablegen
cp /pfad/zu/client-cert.pem /pfad/zu/client-key.key nginx/certs/
chmod 600 nginx/certs/client-key.key

# Konfiguration: Ontoserver-Profil, weniger Arbeitsspeicher
cp .env.default .env
sed -i 's/^COMPOSE_PROFILES=blaze/COMPOSE_PROFILES=ontoserver/; s/^JAVA_OPTS=.*/JAVA_OPTS="-Xmx6g"/' .env

# Ports anpassen: Validator 8082, Proxy 8083
sed -i 's/"8080:8080"/"8082:8080"/; s/"8081:80"/"8083:80"/' docker-compose.yml

docker compose up -d
docker compose logs -f validator-ontoserver
```

<!-- TODO beim Test (Weg 1b noch ungetestet, Test aus dem Büro – dort liegt das Passwort für den privaten Schlüssel): Umwandlung .p12 → PEM ergänzen, Ablauf prüfen, Arbeitsspeicher mit allen 17 IGs prüfen, ggf. IG_PARAMS in .env reduzieren -->

Auch deine eigenen `curl`-Befehle kannst du über den Proxy schicken, ohne Zertifikat anzugeben. Setze `TX` auf den Proxy, dann funktionieren alle Befehle aus [Übung 5 · Codes prüfen](exercise-5.md):

```bash
TX=http://localhost:8083/fhir
curl -s "$TX/metadata" | jq '.software'
```

In diesem Fall startet der Validator gleich mit. Überspringe in [Schritt 2](#schritt-2) das Anlegen der `docker-compose.yml` und mach mit dem Test-Aufruf weiter.

___

## <a id="schritt-2"></a>🛠️ Schritt 2: Validator starten

> ⚠️ **Voraussetzung:** Blaze (Port 8080) läuft, und dein Terminologieserver aus Schritt 1 ist erreichbar. Prüfe das kurz:
>
> ```bash
> # Blaze
> curl -s http://localhost:8080/fhir/metadata | jq '.software'
>
> # Terminologieserver: TX auf den Server aus Schritt 1 setzen (nur eine Zeile ohne #)
> TX=http://localhost:8081/fhir        # A: eigener FHIRsmith
> # TX=http://localhost:8083/fhir      # B: MII Ontoserver über den Proxy
> # TX=https://tx.fhir.org/r4          # C: tx.fhir.org
> curl -s "$TX/metadata" | jq '.software'
> ```

Der Validator läuft wie Blaze und FHIRsmith in einem eigenen Docker-Container. Lege dafür einen eigenen Ordner an:

```bash
mkdir -p ~/validator
cd ~/validator
```

Lege dort die Datei `docker-compose.yml` an. Die Zeile `TX_SERVER` legt fest, welchen Terminologieserver der Validator fragt. Sie zeigt auf deinen FHIRsmith aus Schritt 1a. Hast du tx.fhir.org gewählt, tausche die Adresse wie im Kommentar angegeben:

> 💡 Alle Dienste der Übungen mit Ports und `docker-compose.yml` findest du gesammelt auf der Seite [Dienste](services.md).

```yaml
services:
  validator:
    image: "ghcr.io/medizininformatik-initiative/mii-fhir-validator:0.0.1-alpha.9"
    environment:
      # Arbeitsspeicher für den Validator (Standard des Images: 16 GB)
      JAVA_OPTS: "-Xmx4g"
      # Terminologieserver aus Schritt 1:
      #   A: eigener FHIRsmith auf deinem Rechner: "http://host.docker.internal:8081/fhir"
      #   C: tx.fhir.org:                          "https://tx.fhir.org/r4"
      TX_SERVER: "http://host.docker.internal:8081/fhir"
      # Nur die KDS-Pakete laden, die wir für die Musterdaten brauchen
      IG_PARAMS: >-
        -ig de.basisprofil.r4#1.5.4
        -ig de.medizininformatikinitiative.kerndatensatz.meta#2026.0.0
        -ig de.medizininformatikinitiative.kerndatensatz.base#2026.0.1
        -ig de.medizininformatikinitiative.kerndatensatz.laborbefund#2026.0.3
    extra_hosts:
      - "host.docker.internal:host-gateway"
    ports:
      - "8082:8080"
    volumes:
      - fhir-package-cache:/root/.fhir/packages
      - tx-cache:/tmp/tx-cache

volumes:
  fhir-package-cache:
  tx-cache:
```

🔍 **Genau hinschauen:**

- `ports: "8082:8080"`: Im Container lauscht der Validator auf Port 8080. Da Blaze diesen Port auf deinem Rechner schon belegt, machen wir ihn unter **8082** erreichbar.
- `TX_SERVER`: Die Adresse deines Terminologieservers aus Schritt 1. Für den eigenen FHIRsmith steht hier `host.docker.internal:8081`: Aus Sicht des Containers ist `localhost` der Container selbst, `host.docker.internal` zeigt dagegen auf deinen Rechner. Die Zeile `extra_hosts` macht diesen Namen auch unter Linux bekannt.
- `IG_PARAMS`: Welche Implementation Guides der Validator lädt. Lässt du die Variable weg, lädt er alle 17 MII-Module. Das braucht aber deutlich mehr Arbeitsspeicher und Startzeit.

> 💡 **Arbeitsspeicher:** Blaze (bis 2 GB), FHIRsmith (bis 4 GB) und Validator (bis 4 GB) brauchen zusammen viel Speicher. Wird es auf deinem Rechner knapp, hole dir zuerst die Ressourcen aus Schritt 3 und 4 als Dateien und stoppe danach Blaze (`docker compose down` im Blaze-Ordner).

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

> 🔍 **Genau hinschauen:** Im Log steht, mit welchem Terminologieserver sich der Validator verbunden hat (`Terminology server …`) und welche Pakete er geladen hat (`Package Summary`). Findest du die vier Pakete aus `IG_PARAMS`?

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

Ohne weitere Angaben prüft der Validator gegen die Profile aus `meta.profile`:

```bash
curl -s -X POST http://localhost:8082/validateResource \
  -H "Content-Type: application/fhir+json" \
  --data @hba1c.json \
  | jq '[.issue[] | {severity, text: (.details.text // .diagnostics), ort: (.expression // .location)[0]}]'
```

🔍 **Genau hinschauen:** Was meldet der Validator zu deinem Studienprofil? Kennt er es überhaupt?

<!-- TODO beim Test: erwartete Meldungen eintragen (vermutlich: Profil unbekannt, da das ExampleIG nicht geladen ist) -->

### 3.2 Gegen das MII-Laborprofil validieren

Dein Studienprofil erbt von `MII_PR_Labor_Laboruntersuchung`. Dieses Profil kennt der Validator. Mit dem Parameter `profiles` gibst du es beim Aufruf vor:

```bash
curl -s -X POST "http://localhost:8082/validateResource?profiles=https://www.medizininformatik-initiative.de/fhir/core/modul-labor/StructureDefinition/ObservationLab" \
  -H "Content-Type: application/fhir+json" \
  --data @hba1c.json \
  | jq '[.issue[] | {severity, text: (.details.text // .diagnostics), ort: (.expression // .location)[0]}]'
```

<!-- TODO beim Test: erwartete Meldungen eintragen -->

> 💡 **Eigene Profile laden:** Damit der Validator dein Studienprofil selbst kennt, bräuchte er das Paket deines IG. Der IG Publisher erzeugt es in [Übung 1 · Profil erstellen](exercise-1.md) als `output/package.tgz`. Über `IG_PARAMS` (z. B. `-ig /igs/package.tgz`) und einen eingebundenen Ordner `/igs` kann der Validator es laden. Für diese Übung reicht die Prüfung gegen das MII-Profil.

___

## <a id="schritt-4"></a>💻 Schritt 4: Musterdaten aus Blaze validieren

Jetzt prüfst du echte KDS-Daten. In [Übung 4 · Daten abfragen](exercise-4.md) sind dir dabei schon Auffälligkeiten begegnet. Was sagt der Validator dazu?

### 4.1 Der seltsame Diagnosecode

```bash
curl -s "http://localhost:8080/fhir/Condition?code=570762" | jq '.entry[0].resource' > condition-570762.json

curl -s -X POST http://localhost:8082/validateResource \
  -H "Content-Type: application/fhir+json" \
  --data @condition-570762.json \
  | jq '[.issue[] | {severity, text: (.details.text // .diagnostics), ort: (.expression // .location)[0]}]'
```

<!-- TODO beim Test: erwartete Meldungen eintragen (erwartet: unbekannter ICD-10-GM-Code, ggf. Hinweis zur Profilversion) -->

### 4.2 Eine gültige Diagnose zum Vergleich

```bash
curl -s "http://localhost:8080/fhir/Condition?code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|R51&_count=1" | jq '.entry[0].resource' > condition-r51.json

curl -s -X POST http://localhost:8082/validateResource \
  -H "Content-Type: application/fhir+json" \
  --data @condition-r51.json \
  | jq '[.issue[] | {severity, text: (.details.text // .diagnostics), ort: (.expression // .location)[0]}]'
```

🔍 **Genau hinschauen:** Vergleiche `meta.profile` der Ressource (`jq '.meta.profile' condition-r51.json`) mit den Paketen, die der Validator geladen hat (`IG_PARAMS`). Die Musterdaten wurden 2025 erzeugt und nennen Profilversionen wie `|2025.0.0`. Der Validator kennt die Version 2026. Wie geht er damit um?

<!-- TODO beim Test: Verhalten bei abweichender Profilversion beschreiben -->

### 4.3 Ein Laborwert

```bash
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|718-7&_count=1" | jq '.entry[0].resource' > hb.json

curl -s -X POST http://localhost:8082/validateResource \
  -H "Content-Type: application/fhir+json" \
  --data @hb.json \
  | jq '[.issue[] | {severity, text: (.details.text // .diagnostics), ort: (.expression // .location)[0]}]'
```

🔍 **Genau hinschauen:** Der Laborwert ist mit LOINC kodiert. Kennt dein Terminologieserver LOINC? Auf dem eigenen FHIRsmith aus Schritt 1a ist LOINC nicht geladen, tx.fhir.org kennt LOINC dagegen. Was meldet der Validator in deinem Fall?

<!-- TODO beim Test: erwartete Meldungen für Option A (FHIRsmith) und ggf. B/C eintragen -->

### 4.4 Anzeigetexte mitprüfen

Standardmäßig ignoriert der Validator, ob das `display` zum Code passt. Mit `displayOption=Check` prüft er auch das. Der Validator fragt dafür mit `$validate-code` beim Terminologieserver nach – so wie du es in [Übung 5 · Codes prüfen](exercise-5.md) von Hand gemacht hast:

```bash
curl -s -X POST "http://localhost:8082/validateResource?displayOption=Check" \
  -H "Content-Type: application/fhir+json" \
  --data @condition-r51.json \
  | jq '[.issue[] | {severity, text: (.details.text // .diagnostics)}]'
```

### 🛠️ Aufgabe: Mehrere Diagnosen prüfen

Die folgende Schleife holt die ersten 10 Diagnosen aus Blaze, validiert jede einzeln und zählt die Meldungen je Schwere:

```bash
for id in $(curl -s "http://localhost:8080/fhir/Condition?_count=10" | jq -r '.entry[].resource.id'); do
  curl -s "http://localhost:8080/fhir/Condition/$id" \
    | curl -s -X POST http://localhost:8082/validateResource \
        -H "Content-Type: application/fhir+json" --data @- \
    | jq -c --arg id "${id:0:20}" '{id: $id, meldungen: ([.issue[].severity] | group_by(.) | map({(.[0]): length}) | add)}'
done
```

- Welche Diagnosen haben `error`-Meldungen?
- Sind es bei allen dieselben Meldungen? Lass dir die Texte einer Diagnose mit dem Befehl aus 4.2 ausgeben.

> ⚠️ **Ganze Bundles:** Der Validator kann auch ein komplettes Bundle prüfen. Bei den rund 8.000 Ressourcen aus [Übung 3 · Musterdaten laden](exercise-3.md) dauert das aber sehr lange und braucht viel Speicher. Im DIZ-Alltag validiert man deshalb meist Stichproben oder einzelne Ressourcen direkt in der ETL-Strecke.

Die Berichte aus diesem Schritt wertest du in [Übung 7 · Berichte auswerten](exercise-7.md) genauer aus. Lass die Dateien `hba1c.json`, `condition-570762.json`, `condition-r51.json` und `hb.json` im Ordner `~/validator` liegen.

___

## <a id="vertiefung"></a>🔍 Vertiefung: Kommandozeile und Ausbau des Terminologieservers

### Validator über die Kommandozeile

Der MII FHIR Validator startet intern den HL7-Validator (`validator_cli.jar`) im Server-Modus. Denselben Validator kannst du auch direkt per Kommandozeile aufrufen, z. B. in einer CI-Pipeline. Java hast du seit [Übung 1 · Profil erstellen](exercise-1.md) installiert. Die wichtigsten Parameter:

| Parameter | Bedeutung | Entspricht im MII FHIR Validator |
| --- | --- | --- |
| `-version 4.0.1` | FHIR-Version (R4) | `FHIR_VERSION` |
| `-ig <paket>#<version>` | Implementation Guide laden | `IG_PARAMS` |
| `-tx <url>` | Terminologieserver | `TX_SERVER` |
| `-profile <url>` | Gegen dieses Profil prüfen | Query-Parameter `profiles` |

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

| Schritt | Befehl |
| --- | --- |
| Eigenen Terminologieserver starten | `cd ~/terminology-server && docker compose up -d` |
| Validator starten | `cd ~/validator && docker compose up -d` |
| Start verfolgen | `docker compose logs -f validator` |
| Ressource validieren | `curl -s -X POST http://localhost:8082/validateResource -H "Content-Type: application/fhir+json" --data @ressource.json` |
| Gegen ein Profil validieren | `…/validateResource?profiles=<Profil-URL>` |
| Anzeigetexte mitprüfen | `…/validateResource?displayOption=Check` |
| Ressource direkt aus Blaze validieren | `curl -s <Blaze-URL> \| curl -s -X POST …/validateResource -H "…" --data @-` |
| Validator stoppen | `cd ~/validator && docker compose down` |

**Was du mitnehmen sollst:**

- Ein Validator prüft Ressourcen gegen **Profile**. Welche Profile er kennt, bestimmen die geladenen IG-Pakete.
- Alle Code-Prüfungen gibt er an **einen Terminologieserver** weiter. Was dort nicht geladen ist, kann er nicht prüfen – die Wahl des Terminologieservers bestimmt also, was die Validierung aussagt.
- Profile haben **Versionen**. Daten, die gegen eine ältere Version erzeugt wurden, prüft man nicht automatisch gegen die richtige.

**Ausblick:**

- [Übung 7 · Berichte auswerten](exercise-7.md): Validierungsberichte lesen, filtern und Meldungen einordnen

___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • **6 · Ressourcen validieren** • [7 · Berichte auswerten](exercise-7.md)
___
___
