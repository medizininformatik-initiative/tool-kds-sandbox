___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • **1 · Profil erstellen** • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___

# 🔵 FHIR-Profile definieren und Ressourcen generieren

**Nächste Schritte:**

- Prüfe die Installation der CLI-Tools `sushi` und `fhir`
- Erstelle dein eigenes SUSHI-Projekt mittels `sushi init`
- Experimentiere mit verschiedenen FSH-Definitionen

Grundsätzlich lassen sich FHIR-Profile auf verschiedene Weise spezifizieren. Generell werden Profile in interdisziplinärer Zusammenarbeit von Domänenexpert:innen aus dem medizinischen Bereich und technischen Expert:innen aus dem Datenmanagement und der Modellierung geplant, abgestimmt und umgesetzt.

Dies ist auch beim MII-Kerndatensatz (KDS) der Fall. Der MII-KDS ist in Basis- und Erweiterungsmodule unterteilt und wird kontinuierlich weiterentwickelt. Während die Basismodule fachlich übergreifend definiert sind (z. B. Basis, Labor, Medikation), fokussieren sich die Erweiterungsmodule auf spezifische Anwendungs- und Fachgebiete (z. B. Intensivmedizin, Kardiologie). Weitere Informationen findest du direkt beim [MII Kerndatensatz](https://www.medizininformatik-initiative.de/de/der-kerndatensatz-der-medizininformatik-initiative).

In dieser Übung nutzen wir `FHIR Shorthand` (kurz `FSH`, gesprochen "Fish"). Dies ist eine für die Spezifikation von FHIR entwickelte, domänenspezifische Auszeichnungssprache, mit der sich FHIR-Profile und -Instanzen effizient und lesbar definieren lassen. Die Festlegungen in den `.fsh`-Dateien werden anschließend vom zugehörigen Compiler `SUSHI` verarbeitet, um die finalen FHIR-Strukturdefinitionen (JSON/XML) zu generieren.

📋 Übersicht:

- [SUSHI einrichten (vorbereitend)](#-fsh-compiler-sushi-eingerichtet-npm-installation-)
- [Ressourcen builden (praktisch; basics)](#️-ressourcen-mittels-sushi-builden-️)
- [Anwendungsfallbeispiel (praktisch; KDS-Bezug)](#-beispielprofil-und-beispielressource-in-fsh-definieren-)
- [IG generieren (praktisch; Visualisierung)](#-generierte-ressourcen-menschenlesbar-anzeigen-)

___

## 💻 FSH-Compiler `SUSHI` eingerichtet (NPM-Installation) 💻

SUSHI basiert auf Node.js. Für die Installation nutzen wir den Node Package Manager (npm).

- NPM und Node.js installieren (Beispiel für Linux/Debian):

```bash
sudo apt update && sudo apt install npm nodejs -y
```

- SUSHI installieren und Installation überprüfen:

```bash
npm install -g fsh-sushi
sushi -v
```

Für das Schreiben von FSH-Code wird ein Texteditor mit entsprechender Syntax-Unterstützung empfohlen:

- Visual Studio Code (Empfehlung): Installiere dir hierzu die Extension "FHIR Shorthand" für Syntax-Highlighting, Autocomplete und Fehlererkennung in Echtzeit.
- Alternative (CLI): nano oder vim direkt im Terminal.

Um FHIR-Packages für den Build-Prozess zu verwalten, empfiehlt sich die Installation des `Firely Terminal`:

- `.NET` & `Firely Terminal` installieren

```bash
# 1. .NET installieren (lädt das Skript direkt in die Bash)
wget -qO- https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 8.0 --runtime dotnet

# 2. Umgebungsvariablen automatisch am Ende der ~/.bashrc anhängen
echo -e 'export DOTNET_ROOT=$HOME/.dotnet\nexport PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools' >> ~/.bashrc

# 3. Änderungen für das aktuelle Terminal-Fenster aktivieren
source ~/.bashrc

# 4. Firely Terminal global installieren
dotnet tool install -g firely.terminal

# 5. Installation überprüfen
dotnet --version
fhir --version
```

___

## 🛠️ Ressourcen mittels `SUSHI` builden 🛠️

### 🛠️ Praktische Übung

Um uns der Spezifikation von Profilen und Ressourcen praktisch anzunähern, initiieren wir nun mit SUSHI ein neues FSH-Projekt und starten den Build-Prozess mit der erzeugten Beispiel-FSH-Datei.

#### Erster Schritt

Wechsle in dein Arbeitsverzeichnis und starte das Projekt-Setup (bspw. mit Default-Werten) mittels:

```bash
SUSHI init
cd <PROJECT/FOLDER-NAME>
```

`SUSHI` erzeugt insbesondere die `sushi-config.yaml` und `.fsh`-Definition unter `/input/fsh`.  
Die initiierte Struktur sieht wie folgt aus:

```bash
.
├── _build.bat
├── _build.sh
├── ig.ini
├── input
│   ├── fsh
│   │   └── patient.fsh
│   ├── ignoreWarnings.txt
│   └── pagecontent
│       └── index.md
└── sushi-config.yaml

4 directories, 7 files
```

#### Nächster Schritt

Im Projektverzeichnis die bereits existierende Beispieldatei `patient.fsh` builden mittels:

```bash
sushi
```

Im dadurch gestarteten Build-Prozess löst `SUSHI` Abhängigkeiten auf, lädt notwendige Packages und generiert die FHIR-Strukturdefinitionen (JSON). Die generierten Dateien sind im Ordner fsh-generated zu finden. Dies sieht wie folgt aus:

```bash
.
├── _build.bat
├── _build.sh
├── fsh-generated
│   ├── data
│   │   └── fsh-index.json
│   ├── fsh-index.txt
│   ├── includes
│   │   ├── fsh-link-references.md
│   │   └── menu.xml
│   └── resources
│       ├── ImplementationGuide-fhir.example.json
│       ├── Patient-PatientExample.json
│       └── StructureDefinition-MyPatient.json
├── ig.ini
├── input
│   ├── fsh
│   │   └── patient.fsh
│   ├── ignoreWarnings.txt
│   └── pagecontent
│       └── index.md
└── sushi-config.yaml

8 directories, 14 files
```

Die im Ordner `fsh-generated/resources` auffindbaren JSON-Dateien sind gültige FHIR-Ressourcen passend zu den Definitionen in `/input/fsh/patient.fsh`. Diese sehen wie folgt aus:

```bash
// This is a simple example of a FSH file.
// This file can be renamed, and additional FSH files can be added.
// SUSHI will look for definitions in any file using the .fsh ending.
Profile: MyPatient
Parent: Patient
Description: "An example profile of the Patient resource."
* name 1..* MS

Instance: PatientExample
InstanceOf: MyPatient
Description: "An example of a patient with a license to krill."
* name
  * given[0] = "James"
  * family = "Pond"
```

Eine Übersicht über die Syntax von `FHIR Shorthand` ist durch HL7 veröffentlicht:  
[HL7 FHIR Shorthand Overview](https://hl7.org/fhir/uv/shorthand/overview.html).

Die KDS-Module sind aktuell mit `FHIR Shorthand` umgesetzt und öffentlich auf GitHub einsehbar:  
[MII-KDS-Repositorys auf GitHub](https://github.com/orgs/medizininformatik-initiative/repositories?q=kerndatensatz).

___

## 💻 Beispielprofil und Beispielressource in `fsh` definieren 💻

Wir werden nun ein eigenes Profil definieren, das von einem bestehenden MII-Basisprofil erbt, dieses für den Kontext einer fiktiven klinischen Studie sinnvoll einschränken und abschließend eine passende Beispielressource (Example-Instanz) dazu bauen.

### 📖 Anwendungsfallbeispiel Studie "ZuckerWatch-2026" (Typ-2-Diabetes-Monitoring)

Im Rahmen einer fiktiven multizentrischen klinischen Studie zur Verlaufskontrolle von Patient:innen mit Diabetes mellitus Typ 2 sollen Laborwerte standardisiert erfasst werden. Für die statistische Auswertung ist es zwingend erforderlich, den HbA1c-Wert (glykiertes Hämoglobin) homogen zu modellieren.

Das bestehende Basisprofil der Medizininformatik-Initiative `MII_PR_Labor_Laboruntersuchung` ist bewusst flexibel gehalten, um alle denkbaren Laboruntersuchungen im deutschen Gesundheitswesen abzubilden. Für unsere Studie müssen wir dieses Profil nun restriktiver gestalten, um die Datenqualität bei der späteren Ausleitung und Zusammenführung der Daten zu sichern:

1. Eindeutige Identifikation: Das neue Profil muss fest auf den LOINC-Code 4548-4 (Hemoglobin A1c/Hemoglobin.total in Blood) fixiert werden. Als LOINC-Version soll ausschließlich LOINC 2.82.0 verwendbar sein.

2. Einheitliche Metrik: Um Berechnungsfehler in der Auswertung zu vermeiden, darf der Laborwert ausschließlich in der UCUM-Einheit mmol/mol angegeben werden (andere Einheiten wie % werden für diese Studie ausgeschlossen).

3. Verpflichtende Werte: Der eigentliche Messwert (valueQuantity.value) muss zwingend angegeben sein (Must Support und Kardinalität 1..1).

#### 🛠️ Praktische Übung 2

Gehe nun wie folgt vor, um das Studienprofil und eine dazugehörige Patientendaten-Instanz zu erstellen:

##### Abhängigkeit in sushi-config.yaml eintragen

Öffne die `sushi-config.yaml` und füge unter `dependencies:` das Laborbefund-Modul der MII hinzu, damit SUSHI die Eltern-Strukturdefinitionen auflösen kann:

```bash
dependencies:
  de.medizininformatikinitiative.kerndatensatz.laborbefund: 2026.0.0
```

❗Aktuelle Versionen des KDS findest du in der ["Übersicht über Versionen der Kerndatensatz-Module"](https://github.com/medizininformatik-initiative/kerndatensatz-meta/wiki/Übersicht-über-Versionen-der-Kerndatensatz‐Module).

##### Verschiedene Ressourcen im Projekt strukturieren

`SUSHI` verwendet alle `.fsh`-Dateien im Ordner `/input/fsh` für die Generierung. Die Dateien lassen sich daher flexibel strukturiert ablegen. Für unser Beispiel verwenden wir die Unterordner "profiles" und "examples".

##### Studienprofil anlegen

`input/fsh/profiles/PR_Studie_HbA1c.fsh`

❗ Im Kontext MII KDS sollten die [Namenskonventionen für FHIR-Ressourcen in der MII](https://github.com/medizininformatik-initiative/kerndatensatz-meta/wiki/Namenskonventionen-für-FHIR‐Ressourcen-in-der-MII) berücksichtigt werden.

Erstelle eine neue Datei im Ordner `input/fsh/profiles` namens `PR_Studie_HbA1c.fsh`. Definiere dort ein neues Profil, das von `MII_PR_Labor_Laboruntersuchung` erbt, und setze die oben beschriebenen Einschränkungen (Fixierung von LOINC-Code und UCUM-Einheit sowie Kardinalitäten und Must Support) um.

Neues Profil mit entsprechenden Einschränkungen in `.fsh`-Datei definieren:

```bash
Profile: PR_Studie_HbA1c
Parent: MII_PR_Labor_Laboruntersuchung
Id: pr-studie-hba1c
Title: "ZuckerWatch 2026 - HbA1c Laboruntersuchung"
Description: "Spezifisches Profil für die ZuckerWatch-2026 Studie zur Erfassung des HbA1c-Wertes. Erbt vom MII-Kerndatensatz Modul Labor."

// 1. Fixierung auf den LOINC-Code 4548-4 und die LOINC Version 2.82.0
* code.coding[loinc] 1..1
* code.coding[loinc].version = "2.82.0"
* code.coding[loinc].code = #4548-4
* code.coding[loinc].display = "Hemoglobin A1c/Hemoglobin.total in Blood"

// 2. Verpflichtender Messwert (Kardinalität 1..1 und Must Support)
* valueQuantity 1..1 MS
* valueQuantity.value 1..1 MS

// 3. Einheitliche Metrik: Fixierung auf UCUM-Einheit mmol/mol
* valueQuantity.system = "http://unitsofmeasure.org"
* valueQuantity.code = #mmol/mol
* valueQuantity.unit = "mmol/mol"
```

Unser Ordner sieht damit wie folgt aus:

```bash
./input/fsh/
├── examples
├── patient.fsh
└── profiles
    └── PR_Studie_HbA1c.fsh

3 directories, 2 files
```

##### 🛠️ Valide Beispielressource (Instanz) schreiben

`input/fsh/examples/EXA_Studie_HbA1c.fsh`

Schreibe in einer separaten `.fsh`-Datei eine Instance eines fiktiven Patienten-Messwerts. Nutze als `InstanceOf` das neu erstellte Studienprofil `PR_Studie_HbA1c` und befülle es mit einem realistischen Testwert (z. B. 48 mmol/mol).

Definition der Instance unseres "PR_Studie_HbA1c"-Profils:

```bash
Instance: Example-Studie-HbA1c-01
InstanceOf: PR_Studie_HbA1c
Title: "Beispiel-Instanz für HbA1c Laboruntersuchung"
Description: "Ein konkretes Datenbeispiel (Instance) für die ZuckerWatch-2026 Studie, das die Kriterien des Profils erfüllt."
Usage: #example

// Vom MII-Laboruntersuchungs-Basisprofil geforderte Pflichtfelder
* identifier[analyseBefundCode].type.coding[observationInstanceV2].system = "http://terminology.hl7.org/CodeSystem/v2-0203"
* identifier[analyseBefundCode].type.coding[observationInstanceV2].code = #OBI
* identifier[analyseBefundCode].type.text = "Analyse Befund Code"

* identifier[analyseBefundCode].system = "http://www.acme.com/identifiers/patient"
* identifier[analyseBefundCode].value = "LAB-2026-98765"

* identifier[analyseBefundCode].assigner.reference = "Organization/beispiel-labor"
* identifier[analyseBefundCode].assigner.display = "Zentrallabor Universitätsmedizin"

* status = #final

* category.coding[loinc-observation] = http://loinc.org#26436-6 "Laboratory studies (set)"
* category.coding[observation-category] = http://terminology.hl7.org/CodeSystem/observation-category#laboratory "Laboratory"

* subject = Reference(Patient/example-patient) // Verweis auf unsere (fiktive) Beispiel-Patienten-Instance

* issued = "2026-06-13T16:35:00+02:00"

* effectiveDateTime = 2026-06-17
// Quelle des Datums: Probenentnahme (SNOMED CT, laut ValueSet des MII-Labormoduls)
* effectiveDateTime.extension[QuelleKlinischesBezugsdatum].valueCoding = http://snomed.info/sct#399445004 "Specimen collection date (observable entity)"

// 1. Dein fixierter LOINC-Code (wird hier exakt belegt)
* code.coding[0].version = "2.82.0"
* code.coding[0].system = "http://loinc.org"
* code.coding[0].code = #4548-4
* code.coding[0].display = "Hemoglobin A1c/Hemoglobin.total in Blood"

// 2. Der konkrete Messwert (als Quantity)
* valueQuantity.value = 42.5

// 3. Die fixierte UCUM-Einheit
* valueQuantity.system = "http://unitsofmeasure.org"
* valueQuantity.code = #mmol/mol
* valueQuantity.unit = "mmol/mol"
```

Unser Ordner sieht damit wie folgt aus:

```bash
./input/fsh/
├── examples
│   └── EXA_Studie_HbA1c.fsh
├── patient.fsh
└── profiles
    └── PR_Studie_HbA1c.fsh

3 directories, 3 files
```

###### ⚠️ Häufiger Fehler beim folgenden Build-Prozess – Missing Snapshot

**Hintergrund:**

- **FHIR Packages** sind komprimierte Module (wie npm-Pakete), die FHIR-Ressourcen (Profiles, Extensions, ValueSets) für ein bestimmtes Projekt oder einen Leitfaden bündeln.
- Ein **Snapshot** ist die vollständig ausformulierte, berechnete Version eines FHIR-Profils. Er enthält alle vererbten Elemente der Basis-Ressource. Fehlt der Snapshot, enthält das Profil nur die Abweichungen (das sogenannte *Differential*).

**Das Problem:** Tools wie **SUSHI** benötigen zwingend die vollständigen Snapshots der Paket-Abhängigkeiten, um deine Ressourcen korrekt zu validieren und zu generieren. Wenn ein Paket (z. B. durch automatische Downloads anderer Tools) ohne Snapshots in deinem lokalen FHIR-Cache (`~/.fhir/packages/`) landet, bricht SUSHI mit Fehlermeldungen ab.

Mit den folgenden Varianten erzwingst du das Herunterladen und Generieren bei fehlenden Snapshots:

Variante 1 – Lokale FHIR-Packages verwalten:

```bash
# 1. Das von SUSHI installierte Package ohne Snapshots löschen
rm -r ~/.fhir/packages/de.medizininformatikinitiative.kerndatensatz.laborbefund#2026.0.0

# 2. Das Package frisch installieren
fhir install de.medizininformatikinitiative.kerndatensatz.laborbefund@2026.0.0

# 3. Falls nicht bereits bei der Installation inflated, das Package inflaten und dabei Snapshots generieren lassen
fhir inflate --package de.medizininformatikinitiative.kerndatensatz.laborbefund@2026.0.0 --snapshot --expand --force

# 4. Mit Sushi erfolgreich Ressourcen generieren
sushi .
```

Variante 2 – Package (mit Snapshots) manuell hinterlegen:

Unter `~/.fhir/packages/` das vorhandene Package löschen. Manuell bspw. auf Simplifier das Package (mit Snapshots) herunterladen und in `~/.fhir/packages/` in den zugehörigen Ordner entpacken.

##### ✅ Generierung und Überprüfung

Führe nun abschließend `SUSHI` im Hauptverzeichnis aus. Kontrolliere im Terminal, ob der Build fehlerfrei durchläuft, und prüfe im Ordner `fsh-generated/resources/`, ob die neuen JSON-Strukturdefinitionen erfolgreich erzeugt wurden.

```bash
sushi .
```

Die Rückmeldung von `SUSHI` sollte nun wie folgt aussehen (Wortwitz des Compilers kann abweichen):  

```bash
╔════════════════════════ SUSHI RESULTS ══════════════════════════╗
║ ╭───────────────┬──────────────┬──────────────┬───────────────╮ ║
║ │    Profiles   │  Extensions  │   Logicals   │   Resources   │ ║
║ ├───────────────┼──────────────┼──────────────┼───────────────┤ ║
║ │       2       │      0       │      0       │       0       │ ║
║ ╰───────────────┴──────────────┴──────────────┴───────────────╯ ║
║ ╭────────────────────┬───────────────────┬────────────────────╮ ║
║ │      ValueSets     │    CodeSystems    │     Instances      │ ║
║ ├────────────────────┼───────────────────┼────────────────────┤ ║
║ │         0          │         0         │         2          │ ║
║ ╰────────────────────┴───────────────────┴────────────────────╯ ║
║                                                                 ║
╠═════════════════════════════════════════════════════════════════╣
║ That went swimmingly!                  0 Errors      0 Warnings ║
╚═════════════════════════════════════════════════════════════════╝
```

##### 🔍 Ergebnis ansehen: Was hat SUSHI erzeugt?

Verschaffe dir zuerst einen Überblick über die erzeugten Dateien:

```bash
ls fsh-generated/resources/
```

✅ **Erwartetes Ergebnis:**

```text
ImplementationGuide-fhir.example.json     Patient-PatientExample.json         StructureDefinition-pr-studie-hba1c.json
Observation-Example-Studie-HbA1c-01.json  StructureDefinition-MyPatient.json
```

Der Dateiname setzt sich aus Ressourcentyp und ID zusammen. Sieh dir die Felder deiner Beispiel-Instanz an, die das Profil festlegt:

```bash
jq '{resourceType, id, profil: .meta.profile, code: .code.coding[0], wert: .valueQuantity}' \
  fsh-generated/resources/Observation-Example-Studie-HbA1c-01.json
```

> 💡 `jq` ist ein Kommandozeilenwerkzeug zum Lesen und Filtern von JSON. FHIR-Ressourcen sind oft lange JSON-Dokumente. Der Filter in den einfachen Anführungszeichen wählt aus, was du sehen willst: `{resourceType, id, ...}` baut ein neues Objekt nur aus diesen Feldern, `profil: .meta.profile` holt ein verschachteltes Feld unter einem eigenen Namen. Installiert werden kann es mit `sudo apt install jq -y` (siehe [Voraussetzungen](prerequisites.md)).

Und im Profil selbst: Welche Elemente hat es gegenüber dem Elternprofil verändert? Jedes Element im `differential` hat eine `id` mit seinem Pfad:

```bash
jq -r '.differential.element[].id' fsh-generated/resources/StructureDefinition-pr-studie-hba1c.json
```

✅ **Erwartetes Ergebnis:**

```text
Observation.code.coding
Observation.code.coding.version
Observation.value[x]
Observation.value[x]:valueQuantity
Observation.value[x]:valueQuantity.unit
Observation.value[x]:valueQuantity.code
```

Wo sind Code und Anzeigetext geblieben? Sieh dir die beiden Elemente zu `code` genauer an:

```bash
jq '.differential.element[] | select(.id | startswith("Observation.code"))' \
  fsh-generated/resources/StructureDefinition-pr-studie-hba1c.json
```

✅ **Erwartetes Ergebnis:**

```json
{
  "id": "Observation.code.coding",
  "path": "Observation.code.coding",
  "min": 1,
  "max": "1",
  "patternCoding": {
    "code": "4548-4",
    "system": "http://loinc.org",
    "display": "Hemoglobin A1c/Hemoglobin.total in Blood"
  }
}
{
  "id": "Observation.code.coding.version",
  "path": "Observation.code.coding.version",
  "patternString": "2.82.0"
}
```

🧩 **Was du gerade gesehen hast:**

- Aus jeder `Instance` wird eine Ressource, aus jedem `Profile` eine `StructureDefinition`. In der Instanz stehen genau die Werte aus deiner FSH-Datei, `meta.profile` verweist auf dein Studienprofil.
- Das `differential` des Profils enthält nur sechs Elemente: den Code (`code.coding`) und den Messwert (`value[x]:valueQuantity`) mit den Teilen, die du in `PR_Studie_HbA1c.fsh` festgelegt hast. Alles andere erbt das Profil von `MII_PR_Labor_Laboruntersuchung`. Das ist der Unterschied zwischen Differential und Snapshot aus dem Abschnitt oben.
- Nicht jede Zeile aus der FSH-Datei wird zu einem eigenen Element. SUSHI fasst System, Code und Anzeigetext zu einem `patternCoding` zusammen. Zu `valueQuantity.value` und `valueQuantity.system` steht kein eigenes Element im Differential, obwohl die FSH-Datei Regeln dafür enthält.
- Die Festlegung steht auf `Observation.code.coding` selbst, nicht auf einem Slice `coding:loinc`, und zwar mit `max: "1"`. Dein Profil erlaubt damit genau **ein** Coding, nämlich LOINC `4548-4`. Einen zusätzlichen Hauscode, wie ihn das UKSH bei seinen Laborwerten mitliefert ([Übung 4 · Daten abfragen](exercise-4.md)), ließe es nicht zu. Ob eine FSH-Regel so wirkt wie gedacht, siehst du deshalb am besten im erzeugten Profil.

## 🏁 Generierte Ressourcen menschenlesbar anzeigen 🏁

**Hintergrund:** FHIR-Ressourcen und Implementation Guides (IGs) liegen im Quellcode als reine JSON-, XML- oder FSH-Dateien vor. Für das menschliche Auge – und insbesondere für die spätere Abstimmung mit medizinischem Fachpersonal oder Entwicklern – sind diese Textwüsten schwer lesbar.

Um Profile, ValueSets und Leitfäden in eine strukturierte, interaktive HTML-Ansicht mit Baumstrukturen (ähnlich wie auf Simplifier oder in den offiziellen HL7-Spezifikationen) zu verwandeln, müssen die Daten gerendert werden.

Je nachdem, ob du lokal die vollständige Dokumentation bauen oder nur schnell ein einzelnes Profil prüfen möchtest, stehen dir dafür verschiedene Wege zur Verfügung:

### 💻 Methode 1: Den Publisher mit `Java` ausführen

- Lade die aktuellste Version des `FHIR IG Publishers` herunter und platziere sie einfach auch in deinem SUSHI-Projektordner:

```bash
curl -L https://github.com/HL7/fhir-ig-publisher/releases/latest/download/publisher.jar -o org.hl7.fhir.publisher.jar
```

Hier eine Übersicht über die relevanten Dateien:

```bash
mein-sushi-projekt/
├── input/
│   └── fsh/                # Nur deine .fsh-Dateien
├── ig.ini                  # Konfigurationsdatei für den Publisher
├── sushi-config.yaml       # Hier steuert SUSHI die Seiten
└── org.hl7.fhir.publisher.jar
```

- Starte den Build-Prozess mit Java:

```bash
java -jar org.hl7.fhir.publisher.jar -ig ig.ini -clean
```

**Ergebnis:** Der Publisher lädt die nötigen Abhängigkeiten herunter und generiert einen Ordner namens output/. Darin findest du die fertigen HTML-Dateien (inklusive index.html), die du einfach im Browser betrachten und navigieren kannst.

🔍 Der erzeugte Implementation Guide (IG) kann bspw. über `ExampleIG/output/en/StructureDefinition-pr-studie-hba1c.html` im Browser geöffnet und die definierten Ressourcen in übersichtlicher Darstellung, wie aus Quellen von HL7 oder Simplifier gewohnt, betrachtet und die verschiedenen Ressourcen über Verlinkungen navigiert werden.

Je nach Umfang an zu verarbeitenden Dateien oder verwendeten Codierungen dauert der IG-Build ungefähr 10 Minuten (bei komplexeren Projekten evtl. mehrere Stunden).

Der `FHIR IG Publisher` basiert auf `Java` und nutzt im Hintergrund den statischen Webseiten-Generator `Jekyll` (basierend auf der Programmiersprache Ruby). Ohne `Jekyll` kann der Publisher die HTML-Seiten nicht final rendern. Solltest du `Java` & `Jekyll` noch nicht installiert haben, hier eine kurze Installationsanleitung:

```bash
# 1. Java installieren für Ubuntu / Debian (WSL)
sudo apt update && sudo apt install default-jre default-jdk -y

# 2. Jekyll installieren für Ubuntu / Debian (WSL)
sudo apt update && sudo apt install jekyll -y

# Überprüfung der Installation (erfordert mindestens Java 11 oder höher)
java -version
jekyll -v
```

### 🧩 Alternative "Simplifier.net"

Wenn du deine Profile und den IG online verwalten und als HTML darstellen möchtest:

- Erstelle einen kostenlosen Account auf Simplifier.net.
- Erstelle ein neues Projekt und lade deine ImplementationGuide-JSON sowie die dazugehörigen Ressourcen (wie das Profil `StructureDefinition/MyPatient`) hoch.

`Simplifier` generiert automatisch eine Online-Oberfläche, in der du deinen IG direkt im Browser als strukturierte HTML-Ansicht betrachten und teilen kannst.

### 🧩 Methode 3: Schnelle Vorschau via Online-Tools (FHIR Toolbox || FSH School)

Wenn du keine lokale `Java`-Umgebung einrichten willst und nur schnell sehen möchtest, wie das Ganze als Baumstruktur aussieht, kannst du Online-Tools aus dem FHIR-Ökosystem nutzen:

- Schau auf [FHIR Toolbox](https://fhirtoolbox.com/visualizer) vorbei.
- Schau auf [FSH School / SUSHI Online Compiler](https://fshonline.fshschool.org/#/) vorbei.

❗Die `FHIRToolbox` bietet noch weitere praktische Werkzeuge zum Arbeiten mit und Entwickeln rund um FHIR.

## 🔍 Weiterführende Materialien 🔍

Für die Zwecke unseres Tutorials haben wir nun eine stabile lokale Entwicklungsumgebung zum Arbeiten mit `FHIR Shorthand` und Erstellen von FHIR-Profilen und Ressourcen eingerichtet.

Falls du mehr über `FHIR Shorthand` erfahren möchtest, ist die Website "fshschool.org" mit [umfassender Dokumentation](https://fshschool.org/docs/SUSHI/) sowie einem [Online-FSH-Editor](https://fshonline.fshschool.org) zu empfehlen.

___

### Ausblick

- **Übung 2:** Einfaches Beispiel FHIR-Search (lokal, Ressourcen uploaden, Search)  
- **Übung 3:** KDS-Beispieldaten in FHIR-Server laden (Musterdatenspende, clean_bundle)  
- **Übung 4:** Query von KDS-Daten (Strukturierte Abfragen, Chaining, AND-Suche)

___
___
[Voraussetzungen](prerequisites.md) • [Dienste](services.md) • **1 · Profil erstellen** • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___
