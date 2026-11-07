___
___
[Voraussetzungen](prerequisites.md) • **Dienste** • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___

# 🧩 Dienste

Diese Seite fasst alle Dienste zusammen, die du im Laufe der Übungen startest. Sie dient zum Nachschlagen. Die Übungen selbst leiten dich Schritt für Schritt durch dieselben Dateien und erklären, was die einzelnen Zeilen bedeuten.

___

📋 **Übersicht:**

- [Dienste und Ports](#dienste-und-ports)
- [Blaze (FHIR-Server)](#blaze)
- [FHIRsmith (Terminologieserver)](#fhirsmith)
- [MII FHIR Validator](#validator)
- [Proxy zum MII Ontoserver (optional)](#ontoserver-proxy)
- [Alle Dienste prüfen, stoppen und aufräumen](#befehle)

___

## <a id="dienste-und-ports"></a>📖 Dienste und Ports

| Dienst | Aufgabe | Port | Ordner | Arbeitsspeicher | Eingeführt in |
| --- | --- | --- | --- | --- | --- |
| **Blaze** | FHIR-Server mit den Musterdaten | `8080` | z. B. `~/blaze` | bis 2 GB | [Übung 2 · FHIR-Server starten](exercise-2.md) |
| **FHIRsmith** | Eigener Terminologieserver (ICD-10-GM, OPS, Alpha-ID-SE …) | `8081` | `~/terminology-server` | bis 4 GB | [Übung 6 · Ressourcen validieren](exercise-6.md#schritt-1a) |
| **MII FHIR Validator** | Prüft Ressourcen gegen die KDS-Profile | `8082` | `~/validator` | bis 4 GB | [Übung 6 · Ressourcen validieren](exercise-6.md) |
| **Proxy zum MII Ontoserver** (optional, mit Client-Zertifikat) | Hängt dein Zertifikat an Anfragen an den MII Ontoserver | `8083` | `~/mii-fhir-validator` | gering | [Übung 6 · Ressourcen validieren](exercise-6.md#schritt-1b) |

So arbeiten die Dienste zusammen:

```text
                     Ressource (JSON)                    $validate-code, $expand
  curl  ─────────────────────────────────▶  Validator  ─────────────────────────▶  FHIRsmith
   ▲                                       :8082                                   :8081
   │ Ressourcen hochladen und abfragen
   ▼
 Blaze :8080
```

> 💡 Jeder Dienst hat einen **eigenen Ordner** mit eigener `docker-compose.yml`. `docker compose`-Befehle wirken immer auf die Datei im aktuellen Ordner.
>
> 💡 **Wenig Arbeitsspeicher?** Du brauchst nie alle Dienste gleichzeitig: Für die Übungen 2–5 reicht Blaze. Erst Übung 6 nutzt alle drei.
>
> 💡 **Abweichendes Setup:** Laufen einzelne Dienste bei dir auf einem anderen Rechner, ersetze `localhost` durch dessen Adresse und setze `TX_SERVER` beim Validator auf die URL deines Terminologieservers.

___

## <a id="blaze"></a>💻 Blaze (FHIR-Server)

Eingeführt in [Übung 2 · FHIR-Server starten](exercise-2.md#container-definieren-und-starten). Datei `~/blaze/docker-compose.yml`:

```yaml
services:
  blaze:
    image: "samply/blaze:main"
    environment:
      JAVA_TOOL_OPTIONS: "-Xmx2g"
    ports:
    - "127.0.0.1:8080:8080"
    volumes:
    - "blaze-data:/app/data"
    healthcheck:
      test: [ "CMD", "wget", "--spider", "http://localhost:8080/health" ]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
volumes:
  blaze-data:
```

Starten und prüfen:

```bash
cd ~/blaze
docker compose up -d
curl -s http://localhost:8080/fhir/metadata | jq '.software'
```

___

## <a id="fhirsmith"></a>💻 FHIRsmith (Terminologieserver)

FHIRsmith braucht neben der `docker-compose.yml` noch den Datenordner mit den heruntergeladenen Klassifikationen sowie `library.yml` und `config.json`. Diese legst du in [Übung 6, Schritt 1a](exercise-6.md#schritt-1a) an.

Datei `~/terminology-server/docker-compose.yml`:

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

Starten und prüfen. FHIRsmith liest bei **jedem** Start alle Terminologien neu ein und antwortet erst danach (erster Start ca. 15 Minuten, jeder weitere ca. 5 Minuten):

```bash
cd ~/terminology-server
docker compose up -d
curl -s http://localhost:8081/fhir/metadata | jq '{software: .software, fhirVersion: .fhirVersion}'
```

___

## <a id="validator"></a>💻 MII FHIR Validator

Eingeführt in [Übung 6 · Ressourcen validieren](exercise-6.md#schritt-2). Der Validator braucht deinen FHIRsmith auf Port 8081 (Adresse bei `TX_SERVER`).

Datei `~/validator/docker-compose.yml`:

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

Starten und prüfen (der erste Start dauert ca. 5 Minuten, das Log bleibt anfangs leer):

```bash
cd ~/validator
docker compose up -d
echo '{"resourceType": "Patient"}' \
  | curl -s -X POST http://localhost:8082/validateResource \
      -H "Content-Type: application/fhir+json" \
      --data @- \
  | jq '.issue[].severity'
```

___

## <a id="ontoserver-proxy"></a>💻 Proxy zum MII Ontoserver (optional)

Nur mit Client-Zertifikat der SU-TermServ. Repository klonen und Zertifikat umwandeln: [Übung 6, Schritt 1b](exercise-6.md#schritt-1b).

Starten und prüfen:

```bash
cd ~/mii-fhir-validator
docker compose up -d nginx
curl -s http://localhost:8083/fhir/metadata | jq '.software.name'
```

___

## <a id="befehle"></a>🛠️ Alle Dienste prüfen, stoppen und aufräumen

Welche Container laufen gerade, und auf welchen Ports?

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Logs eines Dienstes ansehen (im jeweiligen Ordner, `Strg+C` beendet die Anzeige):

```bash
docker compose logs -f
```

Dienst stoppen (die Daten bleiben erhalten):

```bash
docker compose down
```

> ⚠️ `docker compose down -v` löscht zusätzlich die Volumes, bei Blaze also **alle hochgeladenen Daten**. Danach musst du die Musterdaten aus [Übung 3 · Musterdaten laden](exercise-3.md) neu laden.
>
> 💡 **Port schon belegt?** Meldet `docker compose up` einen Fehler wie `port is already allocated`, läuft auf dem Port bereits ein anderer Dienst. `docker ps` zeigt, welcher.

___
___
[Voraussetzungen](prerequisites.md) • **Dienste** • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___
