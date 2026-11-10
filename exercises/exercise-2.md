___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • **2 · FHIR-Server starten** • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___

# 🟢 Einfaches Beispiel FHIR-Search

**Nächste Schritte:**

- Prüfe, dass Blaze auf `http://localhost:8080` läuft (`docker ps`)
- Führe die Upload-Befehle für Patient und Observation aus (mit PUT für feste IDs)
- Teste die Search-Abfragen mit verschiedenen Parametern (code, subject, _count)

In [Übung 1 · Profil erstellen](exercise-1.md) haben wir eine HL7 FHIR Structure Definition („PR_Studie_HbA1c“) als .fsh-Datei angelegt, das Profil in der Datei ausdefiniert und abschließend aus der .fsh-Definition die Strukturdefinition per `sushi build` generiert. Des Weiteren haben wir eine Beispiel-Observation-Ressource („Example-Studie-HbA1c-01“) erzeugt. Eine Beispiel-Patient-Ressource war bereits im von `SUSHI` initiierten Projektordner enthalten.

Nun laden wir die beiden generierten Beispielressourcen in einen (lokalen) FHIR-Server hoch und fragen die darin enthaltenen Daten danach per FHIR-Searchstring ab. Zuallererst starten wir dafür einen lokalen FHIR-Server (optional: alternativen FHIR-Server verwenden).

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

- Damit du Docker ohne `sudo` nutzen kannst, nimm deinen Benutzer in die Gruppe `docker` auf. `newgrp docker` aktiviert die Gruppe im aktuellen Terminal. In neuen Terminals gilt sie, nachdem du dich einmal ab- und wieder angemeldet hast:

```bash
sudo usermod -aG docker $USER
newgrp docker
docker run hello-world
```

### Container definieren und starten

Wenn Docker Compose eingerichtet ist, können wir Docker-Container mittels einer Docker-Compose-Datei starten. Als Referenz verwenden wir hierzu den Blaze-Server. Die [Dokumentation zu Samply Blaze](https://blaze-server.org/deployment.html) ist online verfügbar. Die aktuell verfügbare stable-Version ist im [GitHub-Repository des Blaze-Projekts](https://github.com/samply/blaze) als Release ersichtlich. Docker-Images des [samply/blaze sind auf Docker Hub](https://hub.docker.com/r/samply/blaze/tags) verfügbar. Um den Server zu starten, lege eine docker-compose.yml an:

> 💡 Alle Dienste der Übungen mit Ports und `docker-compose.yml` findest du gesammelt auf der Seite [Dienste](services.md).


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

> 💡 `127.0.0.1:` vor dem Port bedeutet: Blaze ist nur von deinem eigenen Rechner aus erreichbar, nicht von anderen Rechnern im Netzwerk.

- Im Ordner mit der Docker-Compose-Datei lässt sich der Dienst danach wie folgt starten und der erfolgreiche Start prüfen:

```bash
# Server starten
docker compose up -d

# Status prüfen (Container Status "Up" und "(healthy)")
docker ps

# Verbindung testen: Software und FHIR-Version aus dem CapabilityStatement
curl -s http://localhost:8080/fhir/metadata | jq '{software, fhirVersion}'
```

> 💡 `/fhir/metadata` liefert das vollständige `CapabilityStatement` des Servers, ein sehr langes JSON-Dokument. Für den Test reicht ein Blick auf zwei Felder: `jq '{software, fhirVersion}'` zeigt nur diese.

- Die Anzeige der laufenden Container sollte den Blaze-FHIR-Server wie folgt auflisten:

```text
IMAGE                STATUS         PORTS
samply/blaze:main    Up (healthy)   127.0.0.1:8080->8080/tcp
```

- Sollte sich der Dienst anders als erwartet verhalten, lassen sich die Docker-Logs einsehen:

```bash
docker compose logs -f -t
```

___

## 💻 FHIR-Server nutzen

### Ressourcen hochladen

Wir laden nun die Beispielressourcen einzeln auf den FHIR-Server hoch. Später im Tutorial werden wir auch noch FHIR-Bundles nutzen, um mehrere Ressourcen gleichzeitig an den FHIR-Server zu übermitteln.

#### Upload Patient

- Gib dem Beispiel-Patienten zuerst eine feste ID: Ergänze in `input/fsh/patient.fsh` bei der Instanz `PatientExample` unter `Description` die Zeile `* id = "example-patient"` und baue das Projekt neu mit `sushi .`. Die Ressource liegt danach als `fsh-generated/resources/Patient-example-patient.json` vor. Wozu die feste ID gut ist, siehst du gleich beim Upload der Observation.

- Upload der Beispiel-Patient-Ressource via `HTTP POST` an den `/Patient`-Endpunkt des FHIR-Servers:

> Voraussetzung: Ressource wurde mittels `sushi .` im SUSHI-Projektordner (Bsp.: `tool-kds-sandbox/solution-exercise-2/ExampleIG`) aus dem zugehörigen `.fsh`-File generiert und ist im Unterordner „fsh-generated“ auffindbar.

```bash
curl -X POST http://localhost:8080/fhir/Patient  \
  -H "Content-Type: application/fhir+json" \
  -d @fsh-generated/resources/Patient-example-patient.json | jq
```

- Antwort des Servers (mit `| jq`):

```json
{
  "resourceType": "Patient",
  "id": "DIKTKJOAOLNYT3Y7",
  "meta": {
    "versionId": "4",
    "lastUpdated": "2026-10-19T08:41:08.887Z",
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

- Da der Server bei einem POST-Request IDs zufällig generiert (z. B. „DHYSYTWMKTNZRTNP“), würde unsere Observation keine gültige Zuordnung haben, wenn sie hart auf `subject`:`Patient/example-patient` referenziert.

##### Feste IDs via HTTP PUT erzwingen

- Um dieses Problem zu lösen, nutzen wir anstelle von `POST` die HTTP-Methode `PUT`. Damit bestimmen wir die ID der Ressource direkt beim Upload selbst.

##### Patient mit selbst festgelegter ID hochladen (`HTTP PUT`)

- Hierbei übergeben wir die ID „example-patient“ direkt am Ende der Endpunkt-URL.

```Bash
curl -X PUT http://localhost:8080/fhir/Patient/example-patient \
  -H "Content-Type: application/fhir+json" \
  -d @fsh-generated/resources/Patient-example-patient.json | jq
```

In der Antwort des Servers steht nun die beim Upload festgelegte ID:
```text
{
  "resourceType": "Patient",
  "id": "example-patient",
```

##### Observation hochladen (PUT)

- Da unsere in Übung 1 definierte Observation (`EXA_Studie_HbA1c.fsh`) bereits die Zeile * subject = Reference(Patient/example-patient) enthält, matcht die Referenz nun mit dem soeben angelegten Patienten.

- Da unser Example zusätzlich auf eine Organisation als „Assigner“ für den identifier „analyseBefundCode“ verweist, müssen wir diese ebenfalls anlegen und in den FHIR-Server hochladen.

Dafür legen wir eine minimal befüllte Organization-Ressource als `Organization-beispiel-labor.fsh`-File im `examples`-Ordner an, bauen diese mittels `sushi .` und laden sie hoch:

Ressource:
```bash
Instance: beispiel-labor
InstanceOf: Organization
Title: "Beispiel-Labor"
Description: "Fiktives Labor, das als Assigner des Laborbefund-Identifiers der ZuckerWatch-2026 Beispiel-Observation dient."
Usage: #example

* active = true
* name = "Zentrallabor Universitätsmedizin"
* type = http://terminology.hl7.org/CodeSystem/organization-type#prov "Healthcare Provider"
```

Upload:

```bash
curl -X PUT http://localhost:8080/fhir/Organization/beispiel-labor \
  -H "Content-Type: application/fhir+json" \
  -d @fsh-generated/resources/Organization-beispiel-labor.json | jq
```

Wir laden nun auch die Observation (mit einer festen ID) via PUT hoch:

```Bash
curl -X PUT http://localhost:8080/fhir/Observation/Example-Studie-HbA1c-01 \
  -H "Content-Type: application/fhir+json" \
  -d @fsh-generated/resources/Observation-Example-Studie-HbA1c-01.json | jq
```

> 💡 **Merkregel für FHIR-Server:**
>
> - **POST:** Der Server generiert eine zufällige ID (z. B. `/fhir/Patient/DHYSYTWMKTNZRTNP`).
> - **PUT:** Du bestimmst die ID selbst, indem du sie an die URL anhängst (z. B. `/fhir/Patient/<EIGENE_ID>`).

#### Ressourcen abfragen

- Zur Abfrage von Ressourcen wird ein „FHIR-Search-String“ als Query-Parameter an die Basis-URL der jeweiligen Ressource angehängt.

##### Beispielabfrage via HTTP-REST

- Um zu überprüfen, welche Patienten aktuell auf dem Server existieren, nutzen wir einen standardmäßigen GET-Request auf den Ressourcen-Endpunkt:

```bash
curl -s "http://localhost:8080/fhir/Patient" | jq
```

Die Antwort ist lang, obwohl nur wenige Patienten im Server liegen. Sieh dir deshalb zuerst den Rahmen an und dann die einzelnen Treffer, je Patient eine Zeile:

```bash
# Art der Antwort und Anzahl der Treffer
curl -s "http://localhost:8080/fhir/Patient" | jq '{resourceType, type, total}'

# Je Treffer: ID und Name
curl -s "http://localhost:8080/fhir/Patient" | jq -r '.entry[].resource | "\(.id)  \(.name[0].given[0]) \(.name[0].family)"'
```

✅ **Erwartetes Ergebnis** (die erste ID ist zufällig und weicht bei dir ab):

```text
{
  "resourceType": "Bundle",
  "type": "searchset",
  "total": 2
}
DIKTKJOAOLNYT3Y7  James Pond
example-patient  James Pond
```

🧩 **Was du gerade gesehen hast:**

- FHIR-Server antworten auf eine Suche immer mit einem `Bundle` vom Typ `searchset`. `total` ist die Anzahl der Treffer, die Ressourcen selbst liegen in `entry`.
- James Pond steht **zweimal** im Server: einmal aus dem `POST` mit zufälliger ID, einmal aus dem `PUT` mit der ID `example-patient`. Ein einfacher `POST` legt bei jedem Aufruf eine neue Ressource an, auch wenn der Inhalt gleich ist. Mit `PUT` passiert das nicht, ein zweiter Aufruf aktualisiert dieselbe Ressource. Auch in [Übung 3 · Musterdaten laden](exercise-3.md) laden wir die Daten per `PUT`, dort vor allem, damit die IDs erhalten bleiben.
- Hast du den `POST` mehrfach ausgeführt, siehst du entsprechend mehr Patienten. Überzählige löschst du wie unten unter [Ressourcen löschen](#ressourcen-löschen-fhir-delete) beschrieben.

##### Gezielte Suche nach Kriterien (FHIR-Search-Parameter)

- FHIR erlaubt es, Suchanfragen über standardisierte Parameter präzise einzuschränken. Du kannst die folgenden Such-Szenarien direkt anhand des gestarteten FHIR-Servers testen:

Die Ausgabe ist bei allen drei Suchen gleich aufgebaut: zuerst die Anzahl der Treffer, dann je Treffer eine Zeile mit ID, Code und Messwert.

1. Suche nach einem spezifischen LOINC-Code  
Möchtest du alle Laborwerte abfragen, die den in unserer Studie fixierten HbA1c-Code aufweisen, filterst du über den Parameter code. Das Trennzeichen | separiert dabei das Codesystem (LOINC) vom eigentlichen Code:

    ```bash
    curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|4548-4" \
      | jq -r '.total, (.entry[]?.resource | "\(.id)  \(.code.coding[0].code)  \(.valueQuantity.value) \(.valueQuantity.unit)")'
    ```

2. Suche über eine Referenz (Reference Search)  
Du kannst gezielt alle Laborwerte abfragen, die exakt zu unserem zuvor angelegten Patienten gehören, indem du über die Patienten-Referenz filterst:

    ```bash
    curl -s "http://localhost:8080/fhir/Observation?subject=Patient/example-patient" \
      | jq -r '.total, (.entry[]?.resource | "\(.id)  \(.code.coding[0].code)  \(.valueQuantity.value) \(.valueQuantity.unit)")'
    ```

3. Kombination mehrerer Parameter (AND-Suche)  
FHIR-Search-Parameter lassen sich mittels eines Kaufmanns-Und (&) beliebig kombinieren. Die folgende Abfrage sucht nach Observations, die sowohl zum Patienten `example-patient` gehören als auch den Status `final` besitzen und deren Messwert `>40` ist. Die zweite Abfrage sucht einen Messwert `<40`:

    ```bash
    curl -s "http://localhost:8080/fhir/Observation?subject=Patient/example-patient&status=final&value-quantity=gt40" \
      | jq -r '.total, (.entry[]?.resource | "\(.id)  \(.code.coding[0].code)  \(.valueQuantity.value) \(.valueQuantity.unit)")'

    curl -s "http://localhost:8080/fhir/Observation?subject=Patient/example-patient&status=final&value-quantity=lt40" \
      | jq -r '.total'
    ```

✅ **Erwartetes Ergebnis:** Die ersten drei Suchen finden dieselbe Observation, die letzte keine:

```text
1
Example-Studie-HbA1c-01  4548-4  42.5 mmol/mol
...
0
```

🧩 **Was du gerade gesehen hast:** Die ersten drei Suchen finden dieselbe Observation. Bei der dritten Suche werden die Parameter mit UND verknüpft: Die Observation muss alle drei Bedingungen erfüllen, und das tut sie (`42.5 > 40`). Bei `lt40` passt keine Observation, `total` ist `0`. Deshalb steht im `jq`-Filter `.entry[]?`: Das `?` verhindert eine Fehlermeldung, falls die Antwort keine Einträge enthält.

##### Ressourcen löschen (FHIR-Delete)

- Solltest du den Server von einer Ressource bereinigen wollen, kannst du Ressourcen über die HTTP-Methode `DELETE` gezielt entfernen. Hierzu musst du den Ressourcentyp und die exakte ID in der URL angeben:

```Bash
curl -X DELETE "http://localhost:8080/fhir/Patient/<RESSOURCEN-ID>" | jq
```

- 💡 Hintergrundwissen (Soft Delete):  
Ein FHIR-Server löscht Daten **in der Regel** nicht physisch aus der Datenbank, um die historische Integrität (z. B. für bestehende Verknüpfungen) zu wahren. Stattdessen wird die Ressource als gelöscht markiert und taucht in Suchen nicht mehr auf. Über `/history` kann auf alte Versionen zugegriffen werden. Beim Löschen muss die referenzielle Integrität berücksichtigt werden. Physisches Löschen ist je nach verwendetem FHIR-Server und Settings via `$purge`-Operation möglich.

___

### Ausblick

- **Übung 3:** KDS-Beispieldaten in FHIR-Server laden (Musterdatenspende, clean_bundle, referenzielle Integrität)  
- **Übung 4:** Query von KDS-Daten (Strukturierte Abfragen, Chaining, AND-Suche)  
- **Übung 5:** Terminologien prüfen mit FHIR-Operationen (Codes am Terminologieserver tx.fhir.org nachschlagen und prüfen)

___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • **2 · FHIR-Server starten** • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___
