___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • **Exercise 3** • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___

# 🟠 Query von KDS-Daten

## Einführung & Kontext

In [Exercise 2](exercise-2.md) haben wir die **Musterdatenspende der DIZe** (UKSH-Standort) in einen lokalen FHIR-Server (Blaze) geladen — ca. 8.400 Ressourcen mit den „DIZ-Flavours“ der Universitätskliniken (UKHD, UKSH, UKW).

In dieser Übung lernst du, strukturierte Abfragen auf diese **KDS-Daten** durchzuführen. Du wirst FHIR-Search-Parameter (LOINC-Code, Chaining, AND, Sortierung, Pagination) auf echte KDS-Ressourcen anwenden und siehst, wie du die Daten für Analysen oder Auswertungen nutzen kannst.

> 💡 **Warum FHIR-Search?**  
> In der DIZ-Praxis greifen duale Auswertungen, Forschungsprojekte oder Export-Skripte fast immer über FHIR-Search auf die integrierten Daten zu. Der FHIR-Search-Standard erlaubt es, flexibel und standortübergreifend auf die Daten zuzugreifen — unabhängig vom zugrundeliegenden Datenbanksystem.

> 💡 **Ausblick: TORCH & DIMP/DUP**  
> Für komplexe Datenanforderungen (z. B. cohortenbasierte Extraktion mit Consent-Check) gibt es im MII-Ökosystem spezialisierte Tools:
> - **[TORCH](https://github.com/medizininformatik-initiative/torch)**: Ein FHIR®-Extraction-Tool für strukturierte, consent-konforme Datenextraktion. TORCH nutzt **CRTDL** (Clinical Resource Transfer Definition Language) und kann entweder CQL oder FLARE für die Kohorten definition verwenden. Ziel: Batch-Extraktion für Forschungsanfragen inkl. MII Consent-Handling.
> - **DIMP/DUP-Pipeline (aether-orchestriert)**: Die Infrastruktur zur automatisierten Datenbereitstellung und -pseudonymisierung für Forschungsprojekte. DIMP (Datenintegrations- und Musterspeicherpipeline) und DUP (Datenauslesepipeline) werden über die aether-Orchestrierung gesteuert — typischerweise im Hintergrund für Exportanfragen aktiv.
>
> Diese Tools sind **nicht Bestandteil dieser praktischen Übung**, aber es ist wichtig zu wissen, dass sie im DIZ-Alltag für large-scale oder consent-komplexe Datenanfragen eingesetzt werden. TORCH ersetzt nicht FHIR-Search, sondern erweitert es um Projekt-basierte, auditierbare Extraktionsketten.

---

📋 **Übersicht:**

- [Grundlagen: FHIR-Search auf KDS-Profilen](#-fhir-search-auf-kds-profilen)
- [Fachliche Beispieldaten-Abfragen](#-fachliche-beispieldaten-abfragen)
- [Skriptbasierter Ausblick (R/Python)](#-skriptbasierter-ausblick-rpython)
- [Zusammenfassung & Merkregeln](#-zusammenfassung--merkregeln)

---

## 💻 FHIR-Search auf KDS-Profilen

FHIR-Search basiert auf Standard-Parametern ( `_search`, `_id`, `_filter`, `_profile` etc.) und Ressourcen-spezifischen Parametern ( ` _count`, `_sort`, `_summary`, ` _contained`, `_include`, `_revinclude`). Wir nutzen hier nur die gängigsten.

> ⚠️ **Voraussetzung:** Blaze läuft noch auf `http://localhost:8080` (aus [Exercise 1/2](exercise-2.md#daten-in-blase-hochladen)). Sollte er nicht mehr laufen: `docker compose up -d` im Blaze-Verzeichnis.

### 1.1 Ressourcentypen in der Musterdatenspende

Prüfe, welche Ressourcentypen Du siehst (UKSH-Daten):

```bash
curl -s "http://localhost:8080/fhir/metadata" | jq '.resource[] | select(.type != "CapabilityStatement" and .type != "StructureDefinition") | .type'
```

Ergebnis (UKSH-Beispiel): `Patient`, `Observation`, `Condition`, `Encounter`, `DiagnosticReport`, `Procedure`, `Location`, `ServiceRequest`, `Practitioner`, `Organization`, `Coverage`, `CareTeam`, `CarePlan`, `Immunization`, `Media`, `DocumentReference`, `DiagnosticReport`, `Observation`, `QuestionnaireResponse`, `Specimen`.

Für die nächsten Abfragen nutzen wir die **KDS-relevanten** Ressourcen:

| Ressource | KDS-Modul-Bezug | Beispiel-Feld |
|-----------|-----------------|---------------|
| `Patient` | KDS-Basis | `name`, `birthDate`, `gender` |
| `Observation` | Labor, Vitalwerte | `code`, `valueQuantity`, `subject` |
| `Condition` | Diagnosen (ICD-10-GM) | `code`, `clinicalStatus`, `verificationStatus`, `subject` |
| `Encounter` | Aufenthalte | `class`, `period`, `location`, `subject` |
| `DiagnosticReport` | Befunde | `code`, `result`, `subject` |
| `Procedure` | Eingriffe | `code`, `performedPeriod`, `subject` |

---

### 1.2 Standard-Search-Parameter

#### **Hintergrund:** FHIR-Search-Parameter

| Parameter | Funktion | Beispiel |
|-----------|----------|----------|
| `_id` | Nach ID filtern | `/Patient?_id=abc123` |
| `_count` | Seite begrenzen | `/Patient?_count=5` (erste 5 Einträge) |
| `_summary` | Response reduzieren | `/Patient?_summary=true` (nur `id`, `resourceType`, `meta`) |
| `_sort` | Sortieren | `/Patient?_sort=_lastUpdated-desc` |
| `_contained` / `_include` / `_revinclude` | Verknüpfte Ressourcen | `/Observation?_include=Observation:subject` |
| `code` | Coding-Filter | `/Observation?code=http://loinc.org\|4548-4` |
| `subject` | Referenz-Filter | `/Observation?subject=Patient/xyz` |

---

#### Praktische Übung: Basis-Abfragen

##### **Abfrage 1: Alle Patienten (mit Pagination)**

```bash
# Erste 5 Patienten
curl -s "http://localhost:8080/fhir/Patient?_count=5" | jq '{
  total: .total,
  link: .link[].url,
  entry_count: (.entry | length),
  Beispiel: .entry[0].resource.name[0]
}'

# Nächste 5 (Pagination über `_offset` oder `_getpages`)
curl -s "http://localhost:8080/fhir/Patient?_count=5&_offset=5" | jq '.total, .entry | length'
```

> 💡 **Merke:** FHIR-Server antworten immer mit einem `Bundle` vom Typ `searchset`. `total` zeigt die Gesamtanzahl an, `entry` enthält die aktuellen Ressourcen für diese „Seite“.

---

##### **Abfrage 2: Observation mit LOINC-Code (HbA1c)**

Nutze den festen LOINC-Code **4548-4** (aus [Exercise 0](exercise-0.md#studienprofil-anlegen)) und filtere nach KDS-Profil (`_profile`) falls verfügbar:

```bash
# 1. Alle Laborwerte mit LOINC 4548-4
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org\|4548-4&_count=3" | jq '{
  total: .total,
  Beispiele: (.entry | .[0:2]) | .[].resource | {
    code: .code.coding[0].display,
    value: .valueQuantity.value,
    unit: .valueQuantity.unit,
    patient: .subject.reference
  }
}'
```

> 💡 **KDS-Hinweis:** Im KDS-Labor-Modul ist dieses Profil definiert. Falls der Server die Profile importiert hat, kannst Du zusätzlich filtern:
> ```bash
> curl -s "http://localhost:8080/fhir/Observation?_profile=http://fhir.de/StructureDefinition/labor-befund&code=http://loinc.org\|4548-4"
> ```

---

##### **Abfrage 3: Verknüpfte Suche (Chaining)**

Alle Laborwerte eines bestimmten Patienten (via `subject`-Referenz):

```bash
# Zuerst: Einen Patienten nach_name suchen (z. B. "Muster")
PATIENT_ID=$(curl -s "http://localhost:8080/fhir/Patient?name=Muster&_count=1" | jq -r '.entry[0].resource.id')

echo "Gefundene Patient-ID: $PATIENT_ID"

# Alle Observationen für diesen Patienten
curl -s "http://localhost:8080/fhir/Observation?subject=Patient/$PATIENT_ID&_count=5" | jq '.entry[].resource | {code: .code.coding[0].display, value: .valueQuantity.value, unit: .valueQuantity.unit}'
```

---

##### **Abfrage 4: AND-Suche (Kombination)**

Observationen mit **mehreren Kriterien** kombinieren (z. B. Laborwert > 48 mmol/mol für einen Patienten):

```bash
# Beispiel: Laborwert > 48 mmol/mol für einen Patienten (nach LOINC 4548-4)
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org\|4548-4&value-quantity=gt48&subject=Patient/$PATIENT_ID&_count=3" | jq '.entry[].resource | {value: .valueQuantity.value, clinical: .clinicalCode?.coding[0].display}'
```

> 💡 **Merke:** Kombinierte Parameter werden als **AND** verknüpft. Ein `OR` erfordert komplexe `_filter`-Ausdrücke (nicht in dieser Übung).

---

##### **Abfrage 5: Sortierung & Limit**

Laborwerte nach Datum sortieren (`issued` oder `effectiveDateTime`):

```bash
# 10 neueste Laborwerte mit LOINC 4548-4
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org\|4548-4&_sort=-issued&_count=10" | jq '.entry[].resource | {date: .effectiveDateTime, value: .valueQuantity.value}'
```

---

### 1.3 Suche auf KDS-Profilen (Ausblick)

Möchtest Du gezielt KDS-Profil-Inhalte abfragen (z. B. alle Observationen aus dem KDS-Labor-Modul), nutze den `_profile`-Parameter mit dem **StructureDefinition-URL** des Profils:

```bash
# Beispiel (funktioniert nur, wenn der Server die KDS-Profile importiert hat):
curl -s "http://localhost:8080/fhir/Observation?_profile=http://fhir.de/StructureDefinition/labor-befund&_count=5" | jq '.entry[].resource.code.coding[0].display'
```

> ⚠️ **Hinweis:** Ob `_profile` funktioniert, hängt davon ab, ob der Server (Blaze) die KDS-Profile geladen hat. In einer echten DIZ-Umgebung wäre dies der Fall.

---

## 💻 Fachliche Beispieldaten-Abfragen

Im Folgenden findest Du typische **Fachabfragen**, die Du im DIZ-Alltag benötigst (Diagnosen, Laborwerte, Aufenthalte). Nutze die Beispiel-ID `PATIENT_ID` aus Abfrage 3 oben.

### 2.1 Alle Diagnosen eines Patienten (ICD-10-GM)

```bash
# Condition mit ICD-10-GM-Diagnosen
curl -s "http://localhost:8080/fhir/Condition?subject=Patient/$PATIENT_ID&_count=5" | jq '.entry[].resource | {
  code: .code.coding[0].code,
  display: .code.coding[0].display,
  clinicalStatus: .clinicalStatus.coding[0].code,
  verification: .verificationStatus.coding[0].code
}'
```

### 2.2 Alle Aufenthalte eines Patienten (Encounter)

```bash
# Encounter mit Klassifizierung (AMB, INA, etc.)
curl -s "http://localhost:8080/fhir/Encounter?subject=Patient/$PATIENT_ID&_count=5" | jq '.entry[].resource | {
  class: .class.display,
  period_start: .period.start,
  period_end: .period.end,
  location: (.location[]?.location.display // "ohne Station") | .[0:40]
}'
```

### 2.3 Gesamtbild: Ressourcen-Verteilung pro Patient

```bash
# Anzahl aller Ressourcen pro Typ für einen Patienten
for resource in Patient Observation Condition Encounter DiagnosticReport Procedure; do
  count=$(curl -s "http://localhost:8080/fhir/$resource?subject=Patient/$PATIENT_ID&_summary=count" | jq '.total')
  echo "$resource: $count"
done
```

---

## 💻 Skriptbasierter Ausblick (R/Python)

Für wiederholte Abfragen, Komplexität oder statistische Auswertungen lohnt sich ein **Skriptansatz**. Hier zwei kurze Beispiele:

### 3.1 Python: fhir-pyrate (Python Library)

```bash
# Installation (optional)
pip install fhir-pyrate

# Minimalbeispiel: Abfrage aller Laborwerte für einen Patienten
python3 <<EOF
from fhirclient import client
from fhirclient.models import observation, patient

settings = {
    'app_id': 'my_app',
    'api_base': 'http://localhost:8080/fhir'
}
smart = client.FHIRClient(settings=settings)

# Patient suchen
PATIENT_ID = '$PATIENT_ID'
obs = observation.Observation.search({'subject': f'Patient/{PATIENT_ID}', 'code': 'http://loinc.org|4548-4'}).perform_resources(smart.server)

print(f'Gefundene Laborwerte: {len(obs)}')
for o in obs[:3]:
    print(f'  {o.effectiveDateTime.isostring}: {o.valueQuantity.value} {o.valueQuantity.unit}')
EOF
```

### 3.2 R: fhircrackr (Library)

```r
# Installation
# install.packages("devtools")
# devtools::install_github("POLAR-fhiR/fhircrackr")

library(fhircrackr)
library(dplyr)

# Verbindung
fhir_con <- fhir_connection("http://localhost:8080/fhir")

# Observationen für einen Patienten abfragen
obs_df <- fhir_query(
  fhir_con,
  resource_type = "Observation",
  query = list(
    subject = paste0("Patient/", PATIENT_ID),
    code = "http://loinc.org|4548-4",
    _count = 10
  )
)

print(obs_df %>% select(effectiveDateTime, valueQuantity.value, valueQuantity.unit))
```

> 💡 **Warum Skripte?**  
> - Automatisierung (tägliche exports, Cronjobs)  
> - Komplexität (mehrere Filterschritte, Aggregationen)  
> - Statistik (ggf. in R/Python direkt weiterarbeiten)  
> - Wiederverwendbarkeit (Versionierung im Git)

> ⚠️ **Hinweis:** Skript-Abfragen erfordern keine Authentifizierung, wenn Blaze ungeschützt läuft. In Live-DIZ muß OAuth/Certs eingerichtet werden (nicht in dieser Übung).

---

## 🏁 Zusammenfassung & Merkregeln

### Warum FHIR-Search?

> ✅ **Standardisiert** — Alle FHIR-Server sprechen dieselbe Sprache  
> ✅ **Flexibel** — Kombiniere Filter, Pagination, Sortierung  
> ✅ **Standort-unabhängig** — DIZ-intern und exportiert gleiches API  

### Wichtigste Parameter im Alltag

| Situation | Parameter | Beispiel |
|-----------|-----------|----------|
| **ID-Suche** | `_id` | `/Patient?_id=abc123` |
| **Code-Suche** | `code` | `/Observation?code=http://loinc.org\|4548-4` |
| **Referenz-Suche** | `subject` | `/Observation?subject=Patient/xyz` |
| **Chaining** | `subject` | `/Observation?subject=Patient/xyz` |
| **AND-Suche** | Kombination | `?code=...&value-quantity=gt48` |
| **Pagination** | `_count`, `_offset` | `?_count=5&_offset=10` |
| **Sortierung** | `_sort` | `?_sort=-issued` |
| **Komprimierung** | `_summary` | `?_summary=true` |

### Ausblick

- **Ex4:** Terminologien laden (bfarm, SNOMED), lokal verfügbar machen  
- **Ex5:** MII FHIR Validator — Profile/Ressourcen checken  
- **Ex6:** Validierungsreport interpretieren  

---

**Nächste Schritte:**  
- Teste die Abfragen lokal (Blaze muss laufen!)  
- Ersetze `PATIENT_ID` mit einer echten ID aus Deiner Datenbasis  
- Erweitere die Abfragen um weitere Filter oder Ressourcen

___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • **Exercise 3** • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___