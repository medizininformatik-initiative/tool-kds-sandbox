[Prerequisites](prerequisites.md) • **Exercise 0** • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
# 🔵 Exercise 0 - FHIR-Profilen definieren und Ressourcen generieren

Grundsätzlich lassen sich FHIR-Profile auf verschiedene Weise spezifizieren. Generell werden Profile in interdisziplinärer Zusammenarbeit von Domänenexpert:innen aus dem medizinischen Bereich und technischen Expert:innen aus dem Datenmanagement und der Modellierung geplant, abgestimmt und umgesetzt.

Dies ist auch beim MII-Kerndatensatz (KDS) der Fall. Der MII-KDS ist in Basis- und Erweiterungsmodule unterteilt und wird kontinuierlich weiterentwickelt. Während die Basismodule fachlich übergreifend definiert sind (z. B. Basis, Labor, Medikation), fokussieren sich die Erweiterungsmodule auf spezifische Anwendungs- und Fachgebiete (z. B. Intensivmedizin, Kardiologie). Weitere Informationen findest du direkt beim [MII Kerndatensatz](https://www.medizininformatik-initiative.de/de/der-kerndatensatz-der-medizininformatik-initiative).

In dieser Übung nutzen wir `FHIR Shorthand` (kurz `FSH`, gesprochen "Fish"). Dies ist eine für die Spezifikation von FHIR entwickelte, domänenspezifische Auszeichnungssprache, mit der sich FHIR-Profile und -Instanzen effizient und lesbar definieren lassen. Die Festlegungen in den `.fsh`-Dateien werden anschließend vom zugehörigen Compiler `SUSHI` verarbeitet, um die finalen FHIR-Strukturdefinitionen (JSON/XML) zu generieren.

Übersicht:
- [SUSHI einrichten (vorbereitend)](#fsh-compiler-sushi-eingerichtet-npm-installation)
- [Ressourcen builden (praktisch; basics)](#ressourcen-mittels-sushi-builden)
- [Anwendungsfallbeispiel (praktisch; KDS-Bezug)](#beispielprofil-und-beispielressource-in-fsh-definieren)

---
## FSH-Compiler `SUSHI` eingerichtet. (NPM-Installation)

SUSHI basiert auf Node.js. Für die Installation nutzen wir den Node Package Manager (npm).

NPM und Node.js installieren (Beispiel für Linux/Debian):
```
sudo apt update && sudo apt install npm nodejs -y
```

SUSHI installieren und Installation überprüfen:
```
npm install -g fsh-SUSHI
SUSHI -v
```

Für das Schreiben von FSH-Code wird ein Texteditor mit entsprechender Syntax-Unterstützung empfohlen:

- Visual Studio Code (Empfehlung): Installiere dir hierzu die Extension "FHIR Shorthand" für Syntax-Highlighting, Autocomplete und Fehlererkennung in Echtzeit.
- Alternative (CLI): nano oder vim direkt im Terminal.

---
## Ressourcen mittels `SUSHI` builden

### Praktische Übung 🛠️

Um uns der Spezifikation von Profilen und Ressourcen praktisch anzunähern, initiieren wir nun mit SUSHI ein neues FSH-Projekt und starten den Build-Process mit der erzeugten Beispiel-FSH-Datei.

#### Erster Schritt: 
Wechseln Sie in Ihr Arbeitsverzeichnis und starten Sie das Projekt-Setup (bspw. mit default Werten) mittels:
```
SUSHI init
cd <PROJECT/FOLDER-NAME>
```

`SUSHI` erzeugt insbesondere die `sushi-config.yaml` und `.fsh`-Definition unter `/input/fsh`.  
Die initiierte Struktur sieht wie folgt aus:
```
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
```
sushi
```

Im dadurch gestarteten Build-Process löst `SUSHI` Abhängigkeiten auf, lädt notwendige Packages und generiert die FHIR Strukturdefinitionen (JSON). Die generierten Dateien sind im Ordner fsh-generated zu finden. Dies sieht wie folgt aus:
```
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
└── SUSHI-config.yaml

8 directories, 14 files
```

Die im Ordner `fsh-generated/resources` auffindbaren JSON-Dateien sind gültige FHIR-Ressourcen passend zu den Definitionen in `/input/fsh/patient.fsh`. Diese sehen wie folgt aus:
```
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
## Beispielprofil und Beispielressource in `fsh` definieren
Wir werden nun ein eigenes Profil definieren, das von einem bestehenden MII-Basisprofil erbt, dieses für den Kontext einer fiktiven klinischen Studie sinnvoll einschränken und abschließend eine passende Beispielressource (Example-Instanz) dazu bauen.

### Anwendungsfallbeispiel Studie "ZuckerWatch-2026" (Typ-2-Diabetes-Monitoring )

Im Rahmen einer fiktiven multizentrischen klinischen Studie zur Verlaufskontrolle von Patient:innen mit Diabetes mellitus Typ 2 sollen Laborwerte standardisiert erfasst werden. Für die statistische Auswertung ist es zwingend erforderlich, den HbA1c-Wert (glykiertes Hämoglobin) extrem homogen zu modellieren.

Das bestehende Basisprofil der Medizininformatik-Initiative `MII_PR_Labor_Laboruntersuchung` ist bewusst flexibel gehalten, um alle denkbaren Laboruntersuchungen im deutschen Gesundheitswesen abzubilden. Für unsere Studie müssen wir dieses Profil nun restriktiver einschränken, um die Datenqualität bei der späteren Ausleitung und Zusammenführung der Daten zu sichern:

1. Eindeutige Identifikation: Das neue Profil muss fest auf den LOINC-Code 4548-4 (Hemoglobin A1c/Hemoglobin.total in Blood) fixiert werden. Als LOINC Version soll ausschließlich LOINC 2.82.0 verwendbar sein.

2. Einheitliche Metrik: Um Berechnungsfehler in der Auswertung zu vermeiden, darf der Laborwert ausschließlich in der UCUM-Einheit mmol/mol angegeben werden (andere Einheiten wie % werden für diese Studie ausgeschlossen).

3. Verpflichtende Werte: Der eigentliche Messwert (valueQuantity.value) muss zwingend angegeben sein (Must Support und Kardinalität 1..1).

#### Praktische Übung 2 🛠️

Gehen Sie nun wie folgt vor, um das Studienprofil und eine dazugehörige Patientendaten-Instanz zu erstellen:

##### Abhängigkeit in sushi-config.yaml eintragen
Öffnen Sie die `sushi-config.yaml` und fügen Sie unter `dependencies:` das Laborbefund-Modul der MII hinzu, damit SUSHI die Eltern-Strukturdefinitionen auflösen kann:
```
dependencies:
  de.medizininformatikinitiative.kerndatensatz.laborbefund: 2026.0.0
```

❗Aktuelle Versionen des KDS finden sie in der ["Übersicht über Versionen der Kerndatensatz-Module"](https://github.com/medizininformatik-initiative/kerndatensatz-meta/wiki/Übersicht-über-Versionen-der-Kerndatensatz‐Module).

##### Verschiedene Ressourcen im Projekt strukturieren

`SUSHI` verwendet alle .fsh-Dateien im Ordner `/input/fsh` für die Generierung. Die Dateien lassen sich daher flexibel strukturiert ablegen. Für unser Beispiel verwenden wir die Unterordner "profiles" und "examples", dies siehtwie folgt aus:
```
./input/
├── fsh
│   ├── examples
│   ├── patient.fsh
│   └── profiles
├── ignoreWarnings.txt
└── pagecontent
    └── index.md

5 directories, 3 files
```

❗ Im Kontext MII KDS sollten die [Namenskonventionen für FHIR-Ressourcen in der MII](https://github.com/medizininformatik-initiative/kerndatensatz-meta/wiki/Namenskonventionen-für-FHIR‐Ressourcen-in-der-MII) berücksichtigt werden.

##### Studienprofil anlegen
`input/fsh/profiles/PR_ZuckWatch_Labor_Hemo.fsh`

Erstellen Sie eine neue Datei im Ordner `input/fsh/profiles` namens `PR_ZuckWatch_Labor_Hemo.fsh`. Definieren Sie dort Ihr neues Profil, das von `MII_PR_Labor_Laboruntersuchung` erbt, und setzen Sie die oben beschriebenen Einschränkungen (Fixierung von LOINC-Code und UCUM-Einheit sowie Kardinalitäten und Must support) um.

##### Valide Beispielressource (Instanz) schreiben
`input/fsh/examples/EXA_ZuckWatch_Labor_Hemo.fsh`

Schreiben Sie in einer separaten `.fsh`-Datei eine Instance eines fiktiven Patienten-Messwerts. Nutzen Sie als `InstanceOf` Ihr neu erstelltes Studienprofil `PR_ZuckWatch_Labor_Hemo` und befüllen Sie es mit einem realistischen Testwert (z. B. 48 mmol/mol).

##### Generierung und Überprüfung
Führen Sie erneut `sushi .` im Hauptverzeichnis aus. Kontrollieren Sie im Terminal, ob der Build fehlerfrei durchläuft, und prüfen Sie im Ordner `fsh-generated/resources/`, ob Ihre neuen JSON-Strukturdefinitionen erfolgreich erzeugt wurden.
```
sushi .
```

###### ⚠️ Häufiger Fehler - Missing Snapshot 

//TODO

## Weiterführende Materialien 🔍
Für die Zwecke unseres Tutorials haben wir nun eine stabile lokale Entwicklungsumgebung zum Arbeiten mit `FHIR Shorthand` und erstellen von FHIR Profilen und Ressourcen eingerichtet.

Falls Du mehr zu `FHIR Shorthand` kennenlernen möchtest, ist die Website "fshschool.org" mit [umfassender Dokumentation](https://fshschool.org/docs/SUSHI/) sowie einem [Online-FSH-Editor](https://fshonline.fshschool.org) zu empfehlen.


___
[Prerequisites](prerequisites.md) • **Exercise 0** • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)