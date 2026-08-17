___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • **Exercise 6** • [Exercise 7](exercise-7.md)
___
___

# 🟤 Interpretieren von Ergebnissen

## Einführung & Kontext

In [Exercise 5](exercise-5.md) hast du gelernt, wie du **FHIR-Ressourcen und -Profile validieren** kannst. Der Validator gibt dabei einen **OperationOutcome** zurück — die „Sprache“ des FHIR-Validierers.

In dieser Übung lernst du, diesen Validierungsbericht zu **interpretieren** — was bedeutet ein `error` vs. ein `warning`? Welche Issues sind kritisch? Wie behebe ich typische Probleme?

> 💡 **Warum Bericht-Interpretation?**  
> - **Datenqualität-Management:** Fokus auf kritische Errors vs. akzeptable Warnings  
> - **Fehlersuche:** Schnelle Lokalisierung von Ursachen  
> - **DIZ-Alltag:** Bei der Validierung von Import-Daten oder Export-Pre-Check  
> - **Audit:** Nachweisbarkeit von Datenqualitätsproblemen und deren Behebung

---

📋 **Übersicht:**

- [Hintergrund: OperationOutcome](#-hintergrund-operationoutcome)
- [Häufige Warnings & Errors](#-häufige-warnings--errors)
- [Beispiel: Bericht analysieren](#-beispiel-bericht-analysieren)
- [Behebungstipps](#-behebungstipps)
- [Zusammenfassung](#-zusammenfassung)

---

## 💻 Hintergrund: OperationOutcome

### 1.1 Struktur eines Validierungsberichts

```json
{
  "resourceType": "OperationOutcome",
  "issue": [
    {
      "severity": "error" | "warning" | "information" | "fatal",
      "code": "invalid" | "structure" | "required" | "binding" | "code-invalid" | "value",
      "details": {
        "coding": [
          {
            "system": "http://terminology.hl7.org/CodeSystem/validation-issue-type",
            "code": "INVALID",
            "display": "Invalid"
          }
        ],
        "text": "Detailed error message"
      },
      "location": [
        "Patient.name[0].family"
      ],
      "expression": [
        "Patient.name"
      ]
    }
  ]
}
```

### 1.2 Severity-Ebenen

| Severity | Bedeutung | Handlung |
|----------|-----------|----------|
| **fatal** | Ressource ist komplett unbrauchbar | **Sofort beheben** — kein Export |
| **error** | Kritische Verletzung des Standards | **Beheben** — Validierung fehlschlägt |
| **warning** | Auffälligkeit, aber konform | **Prüfen** — ggf. Behebung sinnvoll |
| **information** | Hinweis (z. B. „Best Practice“) | **Prüfen** — optional |

---

### 1.3 Code-Typen (validation issue type)

| Code | Beschreibung | Beispiel |
|------|--------------|----------|
| `invalid` | Ressource entspricht nicht dem Schema | Fehlendes Pflichtfeld |
| `structure` | Struktur-Problem | Ungültiges JSON/XML |
| `required` | Pflichtfeld fehlt | `Patient.name` fehlt |
| `binding` | Code nicht im ValueSet | ICD-Code nicht in ICD-10-GM |
| `code-invalid` | Code ungültig | Unbekannter LOINC-Code |
| `value` | Wert außerhalb erlaubter Range | `valueQuantity.value = -10` bei positivem Wert verlangt |

---

## ⚠️ Häufige Warnings & Errors

### 2.1 Pflichtfelder fehlen (required)

**Issue:**
```json
{
  "severity": "error",
  "code": "required",
  "details": {"text": "Field ' Patient.name' is required but was not found"}
}
```

**Ursache:** Das Pflichtfeld `name` fehlt in der Patienten-Ressource.

**Lösung:**
```json
{
  "name": [
    {
      "family": "Muster",
      "given": ["Max"]
    }
  ]
}
```

---

### 2.2 Code nicht im Codesystem (code-invalid / binding)

**Issue:**
```json
{
  "severity": "error",
  "code": "code-invalid",
  "details": {"text": "Code 'ABC123' not found in system 'http://loinc.org'"}
}
```

**Ursache:** Der verwendete Code existiert nicht im LOINC-System (Tippfehler? falsche Version?)

**Lösung:**
- Prüfe den Code auf [loinc.org](https://loinc.org)  
- Prüfe die **Version** (`version` im CodeSystem-Object)  
- Korrigiere den Code oder passe die `version` an

---

### 2.3 Referenz nicht auflösbar (reference)

**Issue:**
```json
{
  "severity": "error",
  "code": "structure",
  "details": {"text": "Reference 'Patient/xxx' does not resolve to a known resource"}
}
```

**Ursache:** Eine Ressource (z. B. Observation) referenziert einen Patienten, der nicht im Server existiert.

**Lösung:**
- Patient existieren lassen (`GET /Patient/xxx` testen)  
- ODER: Dummy-Ressourcen ergänzen (wie in [Ex2 `repair-bundle.sh`](exercise-2.md#bundle-reparieren))  
- ACHTUNG: Nicht alle Validatoren erzwingen referenzielle Integrität

---

### 2.4 ValueQuantity mit ungültiger Einheit (value)

**Issue:**
```json
{
  "severity": "warning",
  "code": "value",
  "details": {"text": "Unit 'mg' should be 'MMOL/L' for this LOINC code"}
}
```

**Ursache:** Die Einheit entspricht nicht dem LOINC-Code-Anforderung (z. B. `HbA1c` erfordert `mmol/mol`, nicht `%`).

**Lösung:**
- Prüfe LOINC-Einheit (`UCUM`-Code im LOINC-Entry)  
- passe `valueQuantity.unit` an (`mmol/mol` für `4548-4`)

---

### 2.5 Profil-Constraint verletzt (structure)

**Issue:**
```json
{
  "severity": "error",
  "code": "structure",
  "details": {"text": "Cardinality violation: expected 1..1, found 0"}
}
```

**Ursache:** Ein profildefiniertes Element hat falsche Kardinalität (z. B. `mustSupport = true` aber nicht gesetzt).

**Lösung:**
- Prüfe das Profil (StructureDefinition)  
- Ergänze das fehlende Element oder passe das Profil an  
- Bei MII-Profilen: siehe [KDS-Module auf GitHub](https://github.com/medizininformatik-initiative)

---

## 📊 Beispiel: Bericht analysieren

### 3.1 Validierungsbericht generieren

```bash
# Invalides Beispiel: Patient ohne name
cat > bad-patient.json <<EOF
{
  "resourceType": "Patient",
  "id": "test-patient",
  "gender": "male",
  "birthDate": "1970-01-01"
}
EOF

# Validieren
curl -X POST http://localhost:8082/fhir/\$validate \
  -H "Content-Type: application/fhir+json" \
  -d @bad-patient.json | jq '.issue[] | {severity, code, details, location}'
```

**Ergebnis:**
```json
[
  {
    "severity": "error",
    "code": "required",
    "details": {"text": "Field 'Patient.name' is required but was not found"},
    "location": ["Patient"]
  }
]
```

---

### 3.2 Bericht filtern (Fokus auf Errors)

```bash
# Nur Errors anzeigen
curl -s ... | jq '.issue[] | select(.severity == "error") | {code, details}'
```

---

### 3.3 Bericht aggregieren (Issues zählen)

```bash
# Wie viele Errors vs. Warnings?
curl -s ... | jq '{
  errors: [.issue[] | select(.severity == "error")] | length,
  warnings: [.issue[] | select(.severity == "warning")] | length,
  infos: [.issue[] | select(.severity == "information")] | length
}'
```

---

## 🔧 Behebungstipps

### 4.1 Fehler-First-Aufbau (CI/CD)

```
1. Errors beheben → 2. Warnings prüfen → 3. Infos optional
└─> Export erst, wenn Errors = 0!
```

### 4.2 Automatisierung (Beispiel: Script)

**script/validate.sh**
```bash
#!/bin/bash
FILE=$1

RESULT=$(curl -s -X POST http://localhost:8082/fhir/\$validate \
  -H "Content-Type: application/fhir+json" \
  -d @$FILE)

ERRORS=$(echo $RESULT | jq '[.issue[] | select(.severity == "error")] | length')
WARNINGS=$(echo $RESULT | jq '[.issue[] | select(.severity == "warning")] | length')

if [ $ERRORS -gt 0 ]; then
  echo "❌ VALIDATION ERROR: $FILES errors found in $FILE"
  echo $RESULT | jq '.issue[] | select(.severity == "error") | {"code", "details"}'
  exit 1
else
  echo "✓ VALIDATION SUCCESS: $WARNINGS warnings (0 errors)"
  exit 0
fi
```

**Aufruf:**
```bash
bash script/validate.sh Patient-Muster.json
```

---

## 🏁 Zusammenfassung

| Issue-Typ | Severity | Handlung |
|-----------|----------|----------|
| **Pflichtfeld fehlt** | `error/required` | Feld ergänzen |
| **Code nicht im System** | `error/code-invalid` | Code prüfen/ersetzen |
| **Referenz nicht aufgelöst** | `error/reference` | Zielressource laden oder Dummies ergänzen |
| **Einheit falsch** | `warning/value` | UCUM-Einheit anpassen |
| **Profil-Constraint** | `error/structure` | Element hinzufügen oder Profil prüfen |

### Quick-Checkliste

- [ ] Errors = 0? ❌ Wenn nein: Beheben  
- [ ] Warnings akzeptabel? ❌ Wenn nein: Prüfen  
- [ ] Validierungsbericht archiviert? ✅ Für Audit!  

---

### Ausblick

- **Ex7:** Ausblick auf Alternativen, Versionierung, Lizenzen  
- **DIZ-Alltag:** Validation in CI/CD-Pipeline (GitLab CI, GitHub Actions)  

---

**Nächste Schritte:**  
- Validiere deine Ressourcen und interpretiere die Berichte  
- Bau ein Script für automatische Validierung  
- Bereite dich auf Ex7 vor

___
___
[Prerequisites](prerequisites.md) • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • **Exercise 6** • [Exercise 7](exercise-7.md)
___
___