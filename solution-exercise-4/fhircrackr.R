library(fhircrackr)

request <- fhir_url(
  url = "http://localhost:8080/fhir",
  resource = "Observation",
  parameters = c(code = "http://loinc.org|718-7", "_count" = "100")
)
bundles <- fhir_search(request = request)

design <- fhir_table_description(
  resource = "Observation",
  cols = c(
    patient = "subject/reference",
    datum   = "effectiveDateTime",
    wert    = "valueQuantity/value",
    einheit = "valueQuantity/unit"
  )
)
df <- fhir_crack(bundles = bundles, design = design)

df$wert <- as.numeric(df$wert)
summary(df$wert)