from fhir_pyrate import Pirate

search = Pirate(auth=None, base_url="http://localhost:8080/fhir", print_request_url=True)

df = search.steal_bundles_to_dataframe(
    resource_type="Observation",
    request_params={"code": "http://loinc.org|718-7", "_count": 100},
    fhir_paths=[
        ("patient", "subject.reference"),
        ("datum", "effectiveDateTime"),
        ("wert", "valueQuantity.value"),
        ("einheit", "valueQuantity.unit"),
    ],
)

print(df.sort_values("datum").head())
print(df["wert"].describe())