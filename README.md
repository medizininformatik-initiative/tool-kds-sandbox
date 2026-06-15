# tool-kds-sandbox

Hier entsteht eine MII Kerndatensatz-Schulungsumgebung. Initiale Übungen werden aus dem Aus-, Fort- und Weiterbildungsprojekt baseTrace heraus erstellt. Die Schulungsumgebung soll Mitte 2026 mit einem initialen Satz an Übungen/Inhalten verfügbar werden. Zukünftig können weitere Übungen/Inhalte entwickelt und hinzugefügt werden.

- Zielgruppe: 
  - Neue Mitarbeitende der DIZe
- Zukünftige Themen:
  - Implementierung von KDS-Profilen
  - Verarbeiten von FHIR-Beispieldaten
  - Validierung von Ressourcen und Profilen

## Prerequisites -> [in den Übungsbereich](exercises/prerequisites.md)
Um die nachfolgenden Übungen lösen zu können, bedarf es einer Entwicklungsumgebung mit GIT, npm, sushi, docker-compose, eines Textbearbeitungsprogramm und minimal 8GB Arbeitsspeicher.

## Exercise 0 - [Vorbereiten der Beispieldaten](exercises/exercise-0.md)

Zu Beginn:
> - FSH-Compiler `Sushi` einrichten
> - (Lokalen) FHIR Store/Server starten

Los geht es:
- Klonen des Beispieldatenrepository
- Builden von FHIR-Ressourcen 
  - Beispieldaten: MII Musterdaten oder MII KDS Testdaten
  - Verwalten von FHIR-Packages (`~./fhir`)
- Laden der Beispieldaten in den FHIR Server

## Exercise 1 - [Aufsetzen eines lokalen Terminologieservers](exercises/exercise-1.md)

- ...
  - --> [MII Validator Quickstart](https://github.com/medizininformatik-initiative/mii-fhir-validator#quick-start) --> [Blaze Termserv](https://samply.github.io/blaze/terminology-service/validation.html)

## Exercise 2 - [Inbetriebnahme des MII FHIR Validators](exercises/exercise-2.md)
- ...

## Exercise 3 - [Starten der Validierung](exercises/exercise-3.md)

- ...

## Exercise 4 - [Interpretieren von Ergebnissen](exercises/exercise-4.md)

## ....

### Kontakt
* Jendrik Richter (UMG) 
* baseTrace-Team