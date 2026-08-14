___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • **Exercise 2** • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___

# 🟡 KDS-Beispieldaten in FHIR-Server laden

In den vorherigen Übungen haben wir gelernt, eigene FHIR-Profile und Instanzen zu definieren (Exercise 0) und diese per `curl` in einen FHIR-Server hochzuladen und abzufragen (Exercise 1).

Jetzt laden wir **echte Beispieldaten** aus der Medizininformatik-Initiative.  
Konkret verwenden wir die **Musterdatenspende der DIZe** – das sind synthetische, aber klinisch realistische Datensätze mehrerer Universitätsklinika (UKHD, UKSH, UKW).  
Anders als die rein technischen Testdaten enthalten sie die **unterschiedlichen "DIZ-Flavours"** (Modellierungsunterschiede zwischen den Standorten) und eignen sich daher besonders gut für realistische Analysen.

📋 **Übersicht:**

- [Musterdatenspende klonen & entpacken](#-musterdatenspende-klonen--entpacken)
- [Transaction-Bundle bauen](#-transaction-bundle-bauen)
- [Referenzielle Integrität prüfen](#-referenzielle-integrität-prüfen)
- [Bundle reparieren](#-bundle-reparieren)
- [Daten in Blaze hochladen](#-daten-in-blaze-hochladen)
- [Upload überprüfen](#-upload-überprüfen)

___

## 💻 Musterdatenspende klonen & entpacken

### 📖 Hintergrund: Musterdaten vs. Testdaten

| | Musterdaten (Musterdatenspende) | Testdaten (MII-Testdaten) |
|---|---|---|
| **Quelle** | DIZe (UKHD, UKSH, UKW) | Technisch generiert |
| **Zweck** | Realistische Anwendungsfälle, verteilte Analysen | Struktur- und Semantiktests |
| **DIZ-Flavour** | ✅ Ja – zeigt Heterogenität | Nein |
| **Referenzielle Integrität** | ⚠️ Nicht immer gegeben | Meist gegeben |

Wir arbeiten im Folgenden mit der **Musterdatenspende**.

### 🛠️ 1. Repository klonen

```bash
git clone https://github.com/medizininformatik-initiative/musterdatenspende-diz.git
cd musterdatenspende-diz
```

Das Repository enthält Daten von drei Standorten:

```bash
UKHD/   # Universitätsklinikum Heidelberg
UKSH/   # Universitätsklinikum Schleswig-Holstein
UKW/    # Universitätsklinikum Würzburg
```

### 🛠️ 2. Daten entpacken

Wähle einen Standort aus. Für dieses Tutorial verwenden wir **UKSH**:

```bash
unzip UKSH/UKSH-2025-11-11.zip
```

> ⚠️ **Hinweis:** Die ZIP-Datei enthält viele einzelne JSON-Dateien (eine pro Ressource). Diese sind als *Searchset*-Bundles formatiert – zum Hochladen müssen wir sie in ein *Transaction*-Bundle umwandeln.

Das entpackte Verzeichnis enthält ca. 270 JSON-Dateien – eine pro Bundle.

```bash
ls UKSH-2025-11-11/ | wc -l
```

___

## 🛠️ Transaction-Bundle bauen

Das Musterdatenspende-Repo enthält im Ordner `bin/` drei Hilfsskripte.  
Das Skript `merge-bundles.sh` wandelt die einzelnen Searchset-Bundles in ein einziges **Transaction-Bundle** um – genau das, was Blaze (und andere FHIR-Server) für den Bulk-Import erwarten.

```bash
bash bin/merge-bundles.sh UKSH-2025-11-11/*.json > transaction-bundle.json
```

### ✅ Zwischenkontrolle

Prüfe die Größe des erzeugten Bundles:

```bash
# Anzahl der Einträge
jq '.total' transaction-bundle.json

# Welche Ressourcentypen sind enthalten?
bash bin/count-resourceTypes.sh UKSH-2025-11-11/*.json
```

Die Ausgabe sollte ca. **8.400 Einträge** mit folgenden Ressourcentypen anzeigen (die genauen Zahlen variieren je nach Standort und Version):

```text
## Ressourcen

| Ressourcen     | Anzahl |
| -------------- | ------ |
| Condition      | 437    |
| Consent        | 5      |
| DiagnosticReport | 1283 |
| Encounter      | 1391   |
| Location       | 63     |
| Observation    | 3537   |
| Patient        | 272    |
| Procedure      | 180    |
| ServiceRequest | 1283   |
```

___

## 🔍 Referenzielle Integrität prüfen

### 📖 Was bedeutet "referenzielle Integrität"?

In FHIR verweisen Ressourcen häufig aufeinander:

- Eine `Observation` hat ein `subject` (`Patient/xyz`)
- Ein `Encounter` hat eine `location` (`Location/xyz`)
- Ein `DiagnosticReport` besteht aus `result`-Referenzen auf `Observation`

Wenn Ressource A auf Ressource B verweist, Ressource B aber nicht im Bundle vorhanden ist, sprechen wir von einer **broken reference** (nicht aufgelösten Referenz).

Die Musterdatenspende ist laut README **bewusst nicht referenziell integer** – ein Nebeneffekt der Anonymisierung. Das ist kein Fehler, aber beim Import müssen wir damit umgehen.

### 🛠️ Broken References ermitteln

Das Skript `unresolved-references.sh` aus dem Musterdatenspende-Repo zeigt dir alle Referenzen an, die im Bundle nicht aufgelöst werden können:

```bash
bash bin/unresolved-references.sh transaction-bundle.json
```

💡 **Erwartetes Ergebnis (UKSH):** Es werden ca. **44 fehlende Referenzen** angezeigt:
- **33 Locations** – klinische Stationen wie `ITSG-HIGHMEDSTAT`, `KINA`, `LCHIR` etc.
- **10 Encounter** – Behandlungsfälle (z. B. `PV-1e5148db8b6ad2187d474ef16b4cb67c39b539bdf4c1c32714973385`)
- **1 Encounter ohne zugehörigen Patienten** – Die Encounter-Dummy-Ressource verweist auf `Patient/dummy` (eine Platzhalter-ID)

> 📌 **Warum fehlen ausgerechnet Locations und Encounter?**  
> Stationskataloge und Behandlungsfall-IDs sind hochgradig standortspezifisch. Bei der Anonymisierung und Extraktion gehen diese Daten leichter verloren als Patientendaten.

___

## 🛠️ Bundle reparieren

### 📖 Zwei Wege zum Ziel

Da **Blaze** (anders als z. B. HAPI) keine Option zum Deaktivieren der referenziellen Integrität bietet, müssen wir die fehlenden Ressourcen vor dem Import ergänzen. Dafür gibt es zwei Strategien:

| Strategie | Vorgehen |
|---|---|
| **A) Dummy-Ressourcen generieren (empfohlen)** | Für jede fehlende Referenz eine minimale Ressource anlegen – die Daten bleiben vollständig. |
| **B) Referenzierende Ressourcen entfernen** | Nicht empfohlen, da sonst wertvolle Daten verloren gehen. |

Wir verwenden Strategie **A** – und dafür gibt es ein Hilfsskript.

### 🛠️ Das repair-bundle.sh Skript

Das Skript `repair-bundle.sh` (im Ordner `tmp-solution_exercise-2/` dieses Repos) macht Folgendes:

1. Es analysiert dein Transaction-Bundle
2. Es identifiziert alle Referenzen, die nicht im Bundle vorhanden sind
3. Es generiert für jede fehlende Ressource eine **minimale Dummy-Ressource** (z. B. `Location`, `Encounter`)
4. Es fügt diese als `PUT`-Einträge (mit selbst gewählter ID) in das Bundle ein
5. Es gibt das reparierte Bundle auf der Standardausgabe aus

So verwendest du es:

```bash
# Vom Hauptverzeichnis des Repos aus:
bash tmp-solution_exercise-2/repair-bundle.sh path/to/transaction-bundle.json \
  > bundle-repaired.json
```

> 💡 **Was passiert genau?**  
> Für eine fehlende Location `ITSG-HIGHMEDSTAT` wird folgende minimale Ressource generiert:
> ```json
> {
>   "resourceType": "Location",
>   "id": "ITSG-HIGHMEDSTAT",
>   "name": "ITSG-HIGHMEDSTAT",
>   "status": "active"
> }
> ```
> Für fehlende Encounter wird eine minimale Encounter-Ressource mit `status: finished` und Klassifizierung `AMB` (ambulant) erzeugt. Die Encounter-Referenzen auf `Patient/dummy` bleiben bestehen – das ist bewusst so, weil die Originaldaten keinen konkreten Patienten für diese Fälle ausweisen.

Das Skript gibt außerdem eine Statistik aus:

```text
═══════════════════════════════════════════════════════════
 repair-bundle.sh – Ergebnis
═══════════════════════════════════════════════════════════
 Fehlende Referenzen gefunden:  44
 Generierte Dummy-Ressourcen:   44
═══════════════════════════════════════════════════════════
```

### 🛠️ Arbeiten mit dem Lösungsskript (Hinweis)

Das Skript `repair-bundle.sh` ist keine "Zauberei" – es wendet lediglich die gleichen Techniken an, die du in den vorherigen Übungen bereits kennengelernt hast:

- **FHIR-Ressourcen definieren** (Exercise 0) – hier nur minimaler
- **FHIR-Ressourcen per PUT hochladen** (Exercise 1) – genau das tun die generierten Entry-Objekte (`"method": "PUT"`)
- **JSON verarbeiten mit `jq`** – das Herzstück des Skripts

> 🚀 **Für Fortgeschrittene:**  
> Versuche, das Skript zu erweitern: Was müsste sich ändern, damit auch andere fehlende Ressourcentypen wie `Practitioner` oder `Organization` automatisch ergänzt werden?

___

## 📤 Daten in Blaze hochladen

Voraussetzung: Blaze läuft noch aus [Exercise 1](exercise-1.md#container-definieren-und-starten).

Jetzt laden wir das reparierte Bundle in den FHIR-Server:

```bash
curl -X POST http://localhost:8080/fhir \
  -H "Content-Type: application/fhir+json" \
  --data @bundle-repaired.json
```

Der Import von ca. 8.400 Ressourcen dauert einige Sekunden. Blaze antwortet mit einem Transaction-Bundle, das den Status jeder einzelnen Operation enthält.

> ⚠️ **Hinweis:** Bei sehr großen Bundles kann Blaze mit einem `413 Payload Too Large` antworten. In dem Fall musst du das Bundle in kleineren Teilen hochladen. Für die UKSH-Daten (ca. 12 MB) sollte es problemlos funktionieren.

### ✅ Zwischenkontrolle

Prüfe, ob der Server die Daten angenommen hat:

```bash
# Wie viele Patienten sind jetzt auf dem Server?
curl -s "http://localhost:8080/fhir/Patient?_summary=count" | jq '.total'

# Wie viele Observationen?
curl -s "http://localhost:8080/fhir/Observation?_summary=count" | jq '.total'

# Wie viele Locations (inkl. unserer Dummy-Locations)?
curl -s "http://localhost:8080/fhir/Location?_summary=count" | jq '.total'
```

💡 **Erwartetes Ergebnis (für UKSH):**

| Ressource | Erwartete Anzahl |
|---|---|
| `Patient` | 272 |
| `Observation` | ~3.537 |
| `Location` | ~96 (63 originale + 33 Dummy-Locations) |
| `Encounter` | ~1.401 (1.391 originale + 10 Dummy-Encounters) |

Sollte die Anzahl der Patienten nicht mit der Erwartung übereinstimmen, lohnt sich ein Blick auf die Blaze-Logs:

```bash
docker compose logs -f blaze
```

___

## ✅ Upload überprüfen

Wir führen noch eine fachliche Abfrage durch, um sicherzustellen, dass die Daten sinnvoll abfragbar sind:

```bash
# Alle Condition-Einträge zu einem Patienten
curl -s "http://localhost:8080/fhir/Condition?subject=Patient/<PATIENTEN-ID>" | jq '.total'

# Alle Laborwerte eines Patienten (aus Exercise 1 bekannt)
curl -s "http://localhost:8080/fhir/Observation?subject=Patient/<PATIENTEN-ID>&_count=5" | jq '.entry[].resource.code.coding[] | select(.system == "http://loinc.org") | {code, display}'
```

> 🏁 **Geschafft!** Du hast erfolgreich echte MII-Musterdaten (mit DIZ-Flavour) in deinen lokalen FHIR-Server geladen – inklusive der Bewältigung des "referenzielle Integrität"-Problems.  
> Im nächsten Schritt ([Exercise 3 – Query von KDS-Daten](exercise-3.md)) wirst du lernen, wie man strukturierte Abfragen auf diese Datenbestände durchführt.

___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • **Exercise 2** • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___
