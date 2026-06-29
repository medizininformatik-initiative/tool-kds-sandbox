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