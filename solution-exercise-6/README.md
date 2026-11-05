# Lösung Übung 6 – Ressourcen validieren

Die Ordner entsprechen den Ordnern, die du in der Übung in deinem Home-Verzeichnis anlegst.

```text
solution-exercise-6/
├── terminology-server/          → ~/terminology-server  (Schritt 1a, FHIRsmith, Port 8081)
│   ├── docker-compose.yml
│   └── data/
│       ├── config.json
│       └── library.yml
└── validator/                   → ~/validator           (Schritt 2, Validator, Port 8082)
    └── docker-compose.yml
```

Die Klassifikationspakete (`data/de.bfarm.icd-10-gm/`, `data/de.bfarm.ops/`, `data/de.bfarm.alpha-id-se/`) sind nicht enthalten. Lade sie wie in [Schritt 1a](../exercises/exercise-6.md#schritt-1a) beschrieben herunter.

Für Schritt 1b (Proxy zum MII Ontoserver) gibt es keine eigenen Dateien: Dort wird die Konfiguration aus dem Repository des MII FHIR Validators verwendet.
