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
- [Container definieren und via docker-compose starten](#container-definieren-und-starten)
- [Ressourcen hochladen](#ressourcen-hochladen)
- [Ressourcen abfragen](#ressourcen-abfragen)

___

## 💻 (Lokaler) FHIR-Server via Docker-Compose gestartet. 💻

Sollte Docker noch nicht auf deinem System vorhanden sein, [installiere dir die für dein Betriebssystem passende Version](https://docs.docker.com/compose/install/linux/#install-using-the-repository).

### Docker einrichten

- Installation (für Ubuntu/Debian):

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-v2
```

- Prüfe nach der Installation, ob Docker erfolgreich läuft:

```bash
docker --version
docker compose version
```

- Standardmäßig benötigt Docker unter Ubuntu Root-Rechte:

```bash
sudo docker run hello-world
```

### Container definieren und starten

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

- Im Ordner mit der Docker-Compose Datei lässt sich der Dienst danach wie folgt starten und der erfolgreiche Start prüfen:

```bash
# Server starten
docker compose up -d

# Status prüfen (Container Status "Up" und "(healthy)")
docker ps

# Verbindung testen (Gibt das CapabilityStatement zurück)
curl -v http://localhost:8080/fhir/metadata
```

- Optional: Installation von `jq` bspw. via `sudo apt  install jq -y`, um mit `curl -v http://localhost:8080/fhir/metadata | jq` eine einfacher menschenlesbare Darstellung zu erhalten.

- Die Anzeige der laufenden Container sollte den Blaze-FHIR-Server wie folgt auflisten:

```text
IMAGE                STATUS         PORTS
samply/blaze:1.9.0   Up (healthy)   0.0.0.0:8080->8080/tcp
```

- Sollte der Dienst anders als erwartet verhalten, lassen sich die Docker-Logs einsehen:

```bash
docker compose logs -f -t
```

___

## 💻 FHIR-Server nutzen

### Ressourcen hochladen

Wir laden nun die Beispielressourcen einzeln auf den FHIR-Server hoch. Später im Tutorial werden wir auch noch FHIR-Bundles nutzen, um mehrere Ressourcen gleichzeitig an den FHIR-Server zu übermitteln.

####  Upload Patient

- Upload der Beispiel-Patient-Ressource via `HTTP POST` an den `/Patient`-Endpunkt des FHIR-Servers:

```bash
curl -X POST http://localhost:8080/fhir/Patient \
  -H "Content-Type: application/fhir+json" \
  -d @ExampleIG/fsh-generated/resources/Patient-PatientExample.json
```

- Antwort des Servers:

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

#### Upload Observation

- Bevor wir die Observation hochladen, müssen wir sicherstellen, dass die referenzielle Integrität gewahrt bleibt. In unserem Fall mit der Ressource `Patient` und einer Ressource `Observation` ist für die Verknüpfung das Element `subject` der Observation-Ressource, welches auf eine Patienten-Ressource verweist, relevant.

- Da der Server bei einem POST-Request IDs zufällig generiert (z. B. "DHYSYTWMKTNZRTNP"), würde unsere Observation keine gültige Zuordnung haben, wenn sie hart auf `subject`:`Patient/example-patient` referenziert.

##### Feste IDs via HTTP PUT erzwingen

- Um dieses Problem zu lösen, nutzen wir anstelle von `POST` die HTTP-Methode `PUT`. Damit bestimmen wir die ID der Ressource direkt beim Upload selbst.

##### Patient mit selbst festgelegter ID hochladen (`HTTP PUT`):
- Hierbei übergeben wir die ID "example-patient" direkt am Ende der Endpunkt-URL.

```Bash
curl -X PUT http://localhost:8080/fhir/Patient/example-patient \
  -H "Content-Type: application/fhir+json" \
  -d @ExampleIG/fsh-generated/resources/Patient-PatientExample.json
```

##### Observation hochladen (PUT):
- Da unsere in Exercise 0 definierte Observation (`EXA_ZuckWatch_Labor_Hemo.fsh`) bereits die Zeile * subject = Reference(Patient/example-patient) enthält, matcht die Referenz nun mit dem soeben angelegten Patienten. Wir laden nun auch die Observation (mit einer festen ID) via PUT hoch:

```Bash
curl -X PUT http://localhost:8080/fhir/Observation/Example-ZuckWatch-Labor-Hemo-01 \
  -H "Content-Type: application/fhir+json" \
  -d @ExampleIG/fsh-generated/resources/Observation-Example-ZuckWatch-Labor-Hemo-01.json
```

<h3>💡 Merkregel für FHIR-Server:</h3>

    > POST: Der Server generiert eine zufällige ID (z. B. /fhir/Patient/DHYSYTWMKTNZRTNP).

    > PUT: Du bestimmst die ID selbst, indem du sie an die URL anhängst (z. B. /fhir/Patient/<EIGENE_ID>).

#### Ressourcen abfragen
- Zur Abfrage von Ressourcen wird ein "FHIR-Search-String" als Query-Parameter an die Basis-URL der jeweiligen Ressource angehängt.

##### Beispielabfrage via HTTP-REST
- Um zu überprüfen, welche Patienten aktuell auf dem Server existieren, nutzen wir einen standardmäßigen GET-Request auf den Ressourcen-Endpunkt:

```Bash
curl -X GET "http://localhost:8080/fhir/Patient" | jq
```

<h3> 💡 Merkregel für FHIR-Server:</h3>

    > FHIR-Server antworten bei Suchabfragen immer mit eine Container-Ressource vom Typ Bundle (mit dem Attribut `type`: `searchset`).

    > Das Feld `total` verrät dir sofort die Anzahl der gefundenen Ressourcen.

    > Die eigentlichen Patientendaten liegen verschachtelt im Array "entry".

##### Gezielte Suche nach Kriterien (FHIR-Search Parameters)
- FHIR erlaubt es, Suchanfragen über standardisierte Parameter präzise einzuschränken. Due kann die folgenden Such-Szenarien direkt anhand des gestarteten FHIR-Servers testen:

1. Suche nach einem spezifischen LOINC-Code  
Möchtest du alle Laborwerte abfragen, die den in unserer Studie fixierten HbA1c-Code aufweisen, filterst du über den Parameter code. Das Trennzeichen | separiert dabei das Codesystem (LOINC) vom eigentlichen Code:

    ```Bash
    curl -X GET "http://localhost:8080/fhir/Observation?code=http://loinc.org|4548-4" | jq
    ```

2. Verknüpfte Suche nach dem Patienten (Chaining / Reference Search)  
Du kannst gezielt alle Laborwerte abfragen, die exakt zu unserem zuvor angelegten Patienten gehören, indem du über die Patienten-Referenz filterst:

    ```Bash
    curl -X GET "http://localhost:8080/fhir/Observation?subject=Patient/example-patient" | jq
    ```

3. Kombination mehrerer Parameter (AND-Suche)  
FHIR-Search-Parameter lassen sich mittels eines Kaufmanns-Und (&) beliebig kombinieren. Die folgende Abfrage sucht nach Observations, die sowohl zum Patienten `example-patient` gehören als auch den Status `final` besitzt und der zugehörige Messwert `>40` ist:

    ```Bash
    curl -X GET "http://localhost:8080/fhir/Observation?subject=Patient/example-patient&status=final&value-quantity=gt40" | jq
    ```

    Eine Suche nach einem Messwert `<40` mit `value-quantity=lt40` würde in unserem Fall, falls keine weiteren Ressourcen hochgeladen wurden eine leeres Antwortbundle zurückliefern.

##### Ressourcen löschen (FHIR-Delete)
- Sollten sich Fehler in deine Testdaten eingeschlichen haben oder Du möchtest  den Server von einer Ressource bereinigen, kannst du Ressourcen über die HTTP-Methode `DELETE` gezielt entfernen. Hierzu musst du den Ressourcentyp und die exakte ID in der URL angeben:

```Bash
curl -X DELETE "http://localhost:8080/fhir/Patient/<RESSOURCEN-ID>"
```

- Hintergrundwissen (Soft Delete):  
Ein FHIR-Server löscht Daten in der Regel nicht physisch aus der Datenbank, um die historische Integrität (z. B. für bestehende Verknüpfungen) zu wahren. Stattdessen wird die Ressource als gelöscht markiert.
Wenn du versucht, diese ID danach erneut direkt via GET aufzurufen, antwortet der Server folgerichtig mit dem HTTP-Status 410 Gone. Bei einer allgemeinen Suchabfrage taucht sie standardmäßig nicht mehr auf.

___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • **Exercise 1** • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___
