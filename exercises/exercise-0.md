___
___
[Prerequisites](prerequisites.md) • **Exercise 0** • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___
# 🔵 FHIR-Profile definieren und Ressourcen generieren

Grundsätzlich lassen sich FHIR-Profile auf verschiedene Weise spezifizieren. Generell werden Profile in interdisziplinärer Zusammenarbeit von Domänenexpert:innen aus dem medizinischen Bereich und technischen Expert:innen aus dem Datenmanagement und der Modellierung geplant, abgestimmt und umgesetzt.

Dies ist auch beim MII-Kerndatensatz (KDS) der Fall. Der MII-KDS ist in Basis- und Erweiterungsmodule unterteilt und wird kontinuierlich weiterentwickelt. Während die Basismodule fachlich übergreifend definiert sind (z. B. Basis, Labor, Medikation), fokussieren sich die Erweiterungsmodule auf spezifische Anwendungs- und Fachgebiete (z. B. Intensivmedizin, Kardiologie). Weitere Informationen findest du direkt beim [MII Kerndatensatz](https://www.medizininformatik-initiative.de/de/der-kerndatensatz-der-medizininformatik-initiative).

In dieser Übung nutzen wir `FHIR Shorthand` (kurz `FSH`, gesprochen "Fish"). Dies ist eine für die Spezifikation von FHIR entwickelte, domänenspezifische Auszeichnungssprache, mit der sich FHIR-Profile und -Instanzen effizient und lesbar definieren lassen. Die Festlegungen in den `.fsh`-Dateien werden anschließend vom zugehörigen Compiler `SUSHI` verarbeitet, um die finalen FHIR-Strukturdefinitionen (JSON/XML) zu generieren.

📋 Übersicht:
- [SUSHI einrichten (vorbereitend)](#-fsh-compiler-sushi-eingerichtet-npm-installation-)
- [Ressourcen builden (praktisch; basics)](#️-ressourcen-mittels-sushi-builden-️)
- [Anwendungsfallbeispiel (praktisch; KDS-Bezug)](#-beispielprofil-und-beispielressource-in-fsh-definieren-)
- [IG generieren (praktisch; Visualisierung)](#-generierte-ressourcen-menschenlesbar-anzeigen-)

---
## 💻 FSH-Compiler `SUSHI` eingerichtet. (NPM-Installation) 💻

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

Um FHIR-Package für den Build-Process zu verwalten emfpiehlt sich die Installation des `Firely Terminals`:
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

---
## 🛠️ Ressourcen mittels `SUSHI` builden 🛠️

### 🛠️ Praktische Übung

Um uns der Spezifikation von Profilen und Ressourcen praktisch anzunähern, initiieren wir nun mit SUSHI ein neues FSH-Projekt und starten den Build-Process mit der erzeugten Beispiel-FSH-Datei.

#### Erster Schritt: 
Wechseln in dein Arbeitsverzeichnis und starten das Projekt-Setup (bspw. mit default Werten) mittels:
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

#### Nächster Schritt: 
Im Projektverzeichnis die bereits existierende Beispieldatei `patient.fsh` builden mittels:
```bash
sushi
```

Im dadurch gestarteten Build-Process löst `SUSHI` Abhängigkeiten auf, lädt notwendige Packages und generiert die FHIR Strukturdefinitionen (JSON). Die generierten Dateien sind im Ordner fsh-generated zu finden. Dies sieht wie folgt aus:
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

Eine Übersicht über die Syntax von `FHIR-Shorthand` ist durch HL7 veröffentlicht:  
[HL7 FHIR Shorthand Overview](https://hl7.org/fhir/uv/shorthand/overview.html).

Die KDS-Module sind aktuell mit `FHIR-Shorthand` umgesetzt und öffentlich auf GitHub einsehbar:  
[MII KDS repositories auf GitHub](https://github.com/orgs/medizininformatik-initiative/repositories?q=kerndatensatz).

---
## 💻 Beispielprofil und Beispielressource in `fsh` definieren 💻
Wir werden nun ein eigenes Profil definieren, das von einem bestehenden MII-Basisprofil erbt, dieses für den Kontext einer fiktiven klinischen Studie sinnvoll einschränken und abschließend eine passende Beispielressource (Example-Instanz) dazu bauen.

### 📖 Anwendungsfallbeispiel Studie "ZuckerWatch-2026" (Typ-2-Diabetes-Monitoring )

Im Rahmen einer fiktiven multizentrischen klinischen Studie zur Verlaufskontrolle von Patient:innen mit Diabetes mellitus Typ 2 sollen Laborwerte standardisiert erfasst werden. Für die statistische Auswertung ist es zwingend erforderlich, den HbA1c-Wert (glykiertes Hämoglobin) extrem homogen zu modellieren.

Das bestehende Basisprofil der Medizininformatik-Initiative `MII_PR_Labor_Laboruntersuchung` ist bewusst flexibel gehalten, um alle denkbaren Laboruntersuchungen im deutschen Gesundheitswesen abzubilden. Für unsere Studie müssen wir dieses Profil nun restriktiver einschränken, um die Datenqualität bei der späteren Ausleitung und Zusammenführung der Daten zu sichern:

1. Eindeutige Identifikation: Das neue Profil muss fest auf den LOINC-Code 4548-4 (Hemoglobin A1c/Hemoglobin.total in Blood) fixiert werden. Als LOINC Version soll ausschließlich LOINC 2.82.0 verwendbar sein.

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
`input/fsh/profiles/PR_ZuckWatch_Labor_Hemo.fsh`

❗ Im Kontext MII KDS sollten die [Namenskonventionen für FHIR-Ressourcen in der MII](https://github.com/medizininformatik-initiative/kerndatensatz-meta/wiki/Namenskonventionen-für-FHIR‐Ressourcen-in-der-MII) berücksichtigt werden.

Erstelle eine neue Datei im Ordner `input/fsh/profiles` namens `PR_ZuckWatch_Labor_Hemo.fsh`. Definiere dort ein neues Profil, das von `MII_PR_Labor_Laboruntersuchung` erbt, und setze die oben beschriebenen Einschränkungen (Fixierung von LOINC-Code und UCUM-Einheit sowie Kardinalitäten und Must support) um.

Neues Profil mit entsprechenden Einschränkungen in `.fsh`-Datei definieren:
```bash
Profile: PR_ZuckWatch_Labor_Hemo
Parent: MII_PR_Labor_Laboruntersuchung
Id: pr-zuckwatch-labor-hemo
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
    └── PR_ZuckWatch_Labor_Hemo.fsh

3 directories, 2 files
```

##### 🛠️ Valide Beispielressource (Instanz) schreiben
`input/fsh/examples/EXA_ZuckWatch_Labor_Hemo.fsh`

Schreibe in einer separaten `.fsh`-Datei eine Instance eines fiktiven Patienten-Messwerts. Nutze als `InstanceOf` das neu erstellte Studienprofil `PR_ZuckWatch_Labor_Hemo` und befülle es mit einem realistischen Testwert (z. B. 48 mmol/mol).

Definition der Instance unseres "PR_ZuckWatch_Labor_Hemo"-Profils: 
```bash
Instance: Example-ZuckWatch-Labor-Hemo-01
InstanceOf: PR_ZuckWatch_Labor_Hemo
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
* effectiveDateTime.extension[QuelleKlinischesBezugsdatum].valueCoding.system = "https://www.medizininformatik-initiative.de/fhir/core/modul-labor/CodeSystem/QuelleKlinischesBezugsdatum"
* effectiveDateTime.extension[QuelleKlinischesBezugsdatum].valueCoding.code = #Probenentnahme
* effectiveDateTime.extension[QuelleKlinischesBezugsdatum].valueCoding.display = "Datum der Probenentnahme"

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
│   └── EXA_ZuckWatch_Labor_Hemo.fsh
├── patient.fsh
└── profiles
    └── PR_ZuckWatch_Labor_Hemo.fsh

3 directories, 3 files
```

###### ⚠️ Häufiger Fehler beim folgenden Build-Process - Missing Snapshot 

**Hintergrund:** 
* **FHIR Packages** sind komprimierte Module (wie npm-Pakete), die FHIR-Ressourcen (Profiles, Extensions, ValueSets) für ein bestimmtes Projekt oder einen Leitfaden bündeln.
* Ein **Snapshot** ist die vollständig ausformulierte, berechnete Version eines FHIR-Profils. Er enthält alle vererbten Elemente der Basis-Ressource. Fehlt der Snapshot, enthält das Profil nur die Abweichungen (das sogenannte *Differential*).

**Das Problem:** Tools wie **SUSHI** benötigen zwingend die vollständigen Snapshots der Paket-Abhängigkeiten, um deine Ressourcen korrekt zu validieren und zu generieren. Wenn ein Paket (z. B. durch automatische Downloads anderer Tools) ohne Snapshots in deinem lokalen FHIR-Cache (`~/.fhir/packages/`) landet, bricht SUSHI mit Fehlermeldungen ab. 

Mit den folgenden Varianten erzwingst du das Herunterladen und Generieren bei fehlenden Snapshots:

Variante 1 - Lokale FHIR-Packages verwalten:
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

Variante 2 - Package (mit Snapshots) manuell hinterlegen:

Unter `~/.fhir/packages/` das vorhandene Package löschen. Manuell bspw. auf Simplifier das Package (mit Snapshots) herunterladen und in `~/.fhir/packages/` in den zugehörigen Ordner entpacken.

##### ✅ Generierung und Überprüfung
Führe nun abschließend `SUSHI` im Hauptverzeichnis aus. Kontrolliere im Terminal, ob der Build fehlerfrei durchläuft, und prüfe im Ordner `fsh-generated/resources/`, ob die neuen JSON-Strukturdefinitionen erfolgreich erzeugt wurden.
```bash
sushi .
```

Die Rückmeldung von `SUSHI` sollte nun wie folgt aussehen (Wortwitz des Compilers kann abweichen):  
```
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

## 🏁 Generierte Ressourcen menschenlesbar anzeigen 🏁

**Hintergrund:** FHIR-Ressourcen und Implementation Guides (IGs) liegen im Quellcode als reine JSON-, XML- oder FSH-Dateien vor. Für das menschliche Auge – und insbesondere für die spätere Abstimmung mit medizinischem Fachpersonal oder Entwicklern – sind diese Textwüsten schwer lesbar. 

Um Profile, ValueSets und Leitfäden in eine strukturierte, interaktive HTML-Ansicht mit Baumstrukturen (ähnlich wie auf Simplifier oder in den offiziellen HL7-Spezifikationen) zu verwandeln, müssen die Daten gerendert werden. 

Je nachdem, ob du lokal die vollständige Dokumentation bauen oder nur schnell ein einzelnes Profil prüfen möchtest, stehen dir dafür verschiedene Wege zur Verfügung:

### 💻  Methode 1: Den Publisher mit `Java` ausführen

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

🔍 Der erzeugte Implementation Guide (IG) kann bspw. über `ExampleIG/output/en/StructureDefinition-pr-zuckwatch-labor-hemo.html` im Browser geöffnet und die definierten Ressourcen in übersichtlicher Darstellung, wie aus Quellen von HL7 oder Simplifier gewohnt, betrachtet und die verschiedenen Ressourcen über Verlinkungen navigiert werden.

Je nach Umfang an zu verarbeitetenden Dateien oder verwendeten Codierungen dauert das IG builden ungefähr 10 Minuten (bei komplexeren Projekten evtl. mehrere Stunden).

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
Wenn du deine Profile und die IG online verwalten und als HTML darstellen möchtest:
- Erstelle einen kostenlosen Account auf Simplifier.net.
- Erstelle ein neues Projekt und lade deine ImplementationGuide-JSON sowie die dazugehörigen Ressourcen (wie das Profil `StructureDefinition/MyPatient`) hoch.

`Simplifier` generiert automatisch eine Online-Oberfläche, in der du deine IG direkt im Browser als strukturierte HTML-Ansicht betrachten und teilen kannst.

### 🧩 Methode 3: Schnelle Vorschau via Online-Tools (FHIR Toolbox || FSH School)
Wenn du keine lokale `Java`-Umgebung einrichten willst und nur schnell sehen möchtest, wie das Ganze als Baumstruktur aussieht, kannst du Online-Tools aus dem FHIR-Ökosystem nutzen:

- Schau auf [FHIR Toolbox](https://fhirtoolbox.com/visualizer) vorbei.
- Schau auf [FSH School / SUSHI Online Compiler](https://fshonline.fshschool.org/#/) vorbei.

❗Die `FHIRToolbox` bietet noch weitere praktische Werkzeuge zum Arbeiten mit FHIR und entwickeln rund um FHIR.

## 🔍 Weiterführende Materialien 🔍
Für die Zwecke unseres Tutorials haben wir nun eine stabile lokale Entwicklungsumgebung zum Arbeiten mit `FHIR Shorthand` und erstellen von FHIR Profilen und Ressourcen eingerichtet.

Falls Du mehr zu `FHIR Shorthand` kennenlernen möchtest, ist die Website "fshschool.org" mit [umfassender Dokumentation](https://fshschool.org/docs/SUSHI/) sowie einem [Online-FSH-Editor](https://fshonline.fshschool.org) zu empfehlen.

___
___
[Prerequisites](prerequisites.md) • **Exercise 0** • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___