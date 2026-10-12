Profile: PR_ZuckWatch_Labor_Hemo
Parent: MII_PR_Labor_Laboruntersuchung
Id: pr-zuckwatch-labor-hemo
Title: "ZuckerWatch 2026 - HbA1c Laboruntersuchung"
Description: "Spezifisches Profil für die ZuckerWatch-2026 Studie zur Erfassung des HbA1c-Wertes. Erbt vom MII-Kerndatensatz Modul Labor."

// 1. Fixierung auf den LOINC-Code 4548-4 und die LOINC Version 2.82.0 
//    Verwendung des bestehenden code.coding-Slices "loinc" aus dem Parent-Profil
* code.coding 1..1
* code.coding.version = "2.82.0"
* code.coding = http://loinc.org#4548-4 "Hemoglobin A1c/Hemoglobin.total in Blood"

// 2. Verpflichtender Messwert (Kardinalität 1..1 und Must Support) als Quantity
* value[x] only Quantity
* valueQuantity 1..1 MS
* valueQuantity.value 1..1 MS

// 3. Einheitliche Metrik: Fixierung auf UCUM-Einheit mmol/mol 
//    (valueQuantity.system ist bereits im Parent-Profil auf UCUM fixiert)
* valueQuantity.code = #mmol/mol
* valueQuantity.unit = "mmol/mol"