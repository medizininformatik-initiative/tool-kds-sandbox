___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • **Exercise 1** • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___

# 🟢 Einfaches Beispiel FHIR-Search

In [Exercise 0](exercise-0.md) haben wir eine HL7 FHIR Structure Definition ("PR_ZuckWatch_Labor_Hemo") als .fsh-Datei angelegt, das Profil in der Datei ausdefiniert und abschließend aus der .fsh-Definition die Strukturdefinition per `sushi build` generiert. Des Weiteren haben wir sowohl eine Beispiel-Observation-Ressource ()"Example-ZuckWatch-Labor-Hemo-01") erzeugt. Ein Beispiel-Patient-Ressource war bereits im von `SUSHI` initiierten Projektordner enthalten.

Nun laden wir die beiden generierten Beispielressourcen in einen (lokalen) FHIR-Server hoch und fragen die darin enthaltenen Daten danach per FHIR-Searchstring ab. Zu aller erst starten wir dafür einen lokalen FHIR-Server (optional: alternativen FHIR-Server verwenden).

📋 Übersicht:

- [Docker einrichten (vorbereitend)](#docker-einrichten)
- [Service definieren und via docker-compose starten](#service-definieren-und-starten)
- TODO

___

## 💻 (Lokaler) FHIR-Server via Docker-Compose gestartet. 💻

### Docker einrichten

Sollte Docker noch nicht auf deinem System vorhanden sein, [installiere dir die passende Version für dein Betriebssystem](https://docs.docker.com/compose/install/linux/#install-using-the-repository).

Für Ubuntu/Debian:

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-v2
```

Prüfe nach der Installation, ob Docker erfolgreich läuft:

```bash
docker --version
docker compose version
```

Standardmäßig benötigt Docker unter Ubuntu Root-Rechte:

```bash
sudo docker run hello-world
```

### FHIR-Server definieren und starten

Wenn Docker Compose eingerichtet ist, können wir Docker-Container mittels einer Docker-Compose Datei starten. Als Referenz verwenden wir hierzu den Blaze-Server. Die [Dokumentation zum Samply/Blaze](https://blaze-server.org/deployment.html) ist online verfügbar. Die aktuell verfügbare stable-Version ist im [Github-Repository des Blaze-Projekts](https://github.com/samply/blaze) als Release ersichtlich. Docker-Images des [samply/blaze sind auf Docker-Hub](https://hub.docker.com/r/samply/blaze/tags) verfügbar. Um den Server zu starten lege eine docker-compose.yml an:

```bash
services:
  blaze:
    image: "samply/blaze:1.9.0@sha256:cba859fb460df3938792226f16ba9bde32bf8dd9edeeadffbd818bccdcce56dc"
    environment:
      JAVA_TOOL_OPTIONS: "-Xmx2g"
    ports:
    - "8080:8080"
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

Im Ordner mit der Docker-Compose Datei lässt sich der Dienst danach wie folgt starten und der erfolgreiche Start prüfen:

```bash
# Server starten
docker compose up -d

# Status prüfen (Container Status "Up" und "(healthy)")
docker ps

# Verbindung testen (Gibt das CapabilityStatement zurück)
curl -v http://localhost:8080/fhir/metadata
```

Optional: Installation von `jq` bspw. via `sudo apt  install jq -y`, um mit `curl -v http://localhost:8080/fhir/metadata | jq` eine einfacher menschenlesbare Darstellung zu erhalten.

Die Anzeige der laufenden Container sollte den Blaze-FHIR-Server wie folgt auflisten:

```text
IMAGE                STATUS         PORTS
samply/blaze:1.9.0   Up (healthy)   0.0.0.0:8080->8080/tcp
```

Sollte der Dienst anders als erwartet verhalten, lassen sich die Docker-Logs einsehen:

```bash
docker compose logs -f -t
```

___

## FHIR-Server nutzen

### Ressourcen hochladen

Wir laden nun die Beispielressourcen einzeln auf den FHIR-Server hoch. Später im Tutorial werden wir auch noch FHIR-Bundles nutzen, um mehrere Ressourcen gleichzeitig an den FHIR-Server zu übermitteln.

- Upload der Beispiel-Patient-Ressource via `HTTP POST` an den /fhir-Endpunkt des FHIR-Servers:

```bash
curl -X POST http://localhost:8080/fhir/Patient \
  -H "Content-Type: application/fhir+json" \
  -d @ExampleIG/fsh-generated/resources/Patient-PatientExample.json
```

Antwort des Servers:

```json
{
  "resourceType": "Patient",
  "id": "DHYSYTWMKTNZRTNP",
  "meta": {
    "versionId": "3",
    "lastUpdated": "2026-06-29T09:45:23.426Z",
    "profile": [
      "http://example.org/StructureDefinition/MyPatient"
    ]
  },
  "name": [
    {
      "family": "Pond",
      "given": [
        "James"
      ]
    }
  ]
}
```

- Upload der Beispiel-Observation-Ressource via `HTTP POST`:

```bash

```

### Beispielabfrage via HTTP-REST

TODO

```bash
curl -X GET "http://localhost:8080/fhir/Patient"
```
___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • **Exercise 1** • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___
