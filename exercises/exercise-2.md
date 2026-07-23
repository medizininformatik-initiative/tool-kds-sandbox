___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • **Exercise 2** • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___

# 🟡 KDS-Beispieldaten in FHIR-Server laden

Abgrenzung: Musterdaten sind Beispieldaten die realtweltliche Gegebenheiten widerspiegeln. Testdaten sind Beispieldaten die in erster Linie technische Anforderungen (z.B. Semantik) erfüllen.

In diesem Beispiel wollen wir von **Datenintegrationszentren (DIZ)** verschiedener Universitätsklinika öffentlich zur Verfügung gestellte **Musterdaten** als Beispieldaten in einen FHIR-Server laden. Die Daten sind anonymisiert und spiegeln die **technische Heterogenität** der Daten verschiedener DIZ wider. Dies erlaubt interessante Einblicke und **realistische Anwendungstests** insbesondere für **verteilte Analysen**.

- **KDS-Musterdatenspende**:  
https://github.com/medizininformatik-initiative/musterdatenspende-diz

- **KDS-Testdaten**:  
https://github.com/medizininformatik-initiative/mii-testdata

- Passend dazu:   
    Repo mit Anleitung zum Starten verschiedener FHIR-Server   
    https://github.com/medizininformatik-initiative/fhir-server-examples

Für unsere Tutorial gehen wir im Weiteren von dem, wie in [Exercise 1](exercise-1.md#container-definieren-und-starten) gestarteten, Blaze-FHIR Server aus.

📋 Übersicht:

- [link](#asdasd)
- [link](#asdasd)
- [link](#asdasd)
- [link](#asdasd)

## asd

1. Musterdaten repo pullen

Achtung daten nicht vollständig referenziell integer  
--> bedingt durch die anonymisierung?  
Nicht auflösende daten rausnehmen mit `bash bin/unresolved-references.sh transaction-bundle.json` 

2. upload der daten

___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • **Exercise 2** • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___
