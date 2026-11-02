___
___
[Prerequisites](prerequisites.md) • [Dienste](services.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • **Exercise 6** • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
___
___

# 🟣 Nutzen eines FHIR Validators

**Nächste Schritte:**

- Starte den **MII FHIR Validator** per Docker Compose und verbinde ihn mit deinem Terminologieserver aus [Exercise 5](exercise-5.md)
- Validiere deine HbA1c-Observation aus [Exercise 1](exercise-1.md) gegen das MII-Laborprofil
- Validiere einzelne Musterdaten aus Blaze, darunter die Auffälligkeiten aus [Exercise 4](exercise-4.md)

Ob eine FHIR-Ressource formal in Ordnung ist, lässt sich schnell und ohne Installation prüfen: Webtools wie fhirtoolbox.com laufen im Browser, finden Tippfehler, falsche Datentypen oder fehlende Pflichtfelder und liefern sofort Rückmeldung. Auch SUSHI weist beim Build auf Fehler im FSH-Quelltext hin, etwa auf Syntaxfehler oder unbekannte Elementpfade. Das reicht aber nur für die Struktur. Ob ein Code wirklich existiert, zum vorgeschriebenen ValueSet gehört und ein passendes Display hat, oder ob die Ressource das richtige Profil erfüllt, kann ein solches Tool nicht beurteilen. Dafür braucht es einen **Validator**, der die Profile kennt, und einen **Terminologieserver**, der die Codes prüft. Erst diese Kombination zeigt, ob eine Ressource nicht nur „gut aussieht“, sondern den Vorgaben des Kerndatensatzes entspricht.

> 💡 **Ausblick:** In [Exercise 7](exercise-7.md) lernst du, die Validierungsberichte aus dieser Übung **zu interpretieren** und einzuordnen.

___

📋 **Übersicht:**

- [Hintergrund: Was prüft ein Validator?](#hintergrund)
- [Aufbau: Drei Server, drei Ports](#aufbau)
- [Schritt 1: Validator starten](#schritt-1)
- [Schritt 2: Eigene Ressource validieren](#schritt-2)
- [Schritt 3: Musterdaten aus Blaze validieren](#schritt-3)
- [Vertiefung: Validator über die Kommandozeile](#vertiefung)
- [Zusammenfassung und Ausblick](#zusammenfassung)

___

## <a id="hintergrund"></a>📖 Hintergrund: Was prüft ein Validator?

### Strukturelle Validierung vs. Conformance-Validierung

| Prüfebene | Strukturell (z. B. fhirtoolbox.com) | Conformance (HL7 Validator, IG Publisher, MII FHIR Validator) |
|---|---|---|
| **Frage** | Ist das gültiges FHIR-JSON? | Entspricht die Ressource dem Standard und den Profilen? |
| **Syntax / Datentypen** | ✅ | ✅ |
| **Pflichtelemente / Kardinalität** | Teilweise (nur ausgewählte Ressourcen) | ✅ Alle Elemente laut Profil |
| **Invarianten (FHIRPath)** | ❌ | ✅ |
| **Profile / IGs / Slicing** | ❌ | ✅ |
| **Codes in fest eingebauten Listen** (z. B. `gender`) | ✅ | ✅ |
| **Code existiert im CodeSystem?** | ❌ | ✅ via Terminologieserver (`$validate-code`) |
| **Code gehört zum gebundenen ValueSet?** | ❌ | ✅ via Terminologieserver |
| **Display passt zum Code?** | ❌ | ✅ via Terminologieserver (optional) |
| **Terminologieserver nötig?** | Nein | Ja |
| **Typischer Einsatz** | Schneller Check beim Schreiben | Vor Release, in CI, in der ETL-Strecke |

> ⚠️ **Grenzen:** Ein Validator prüft **nicht**, ob Inhalte fachlich plausibel sind (z. B. ein Laborwert von 300 g/dL Hämoglobin) oder ob Code und Einheit fachlich zusammenpassen. Ob referenzierte Ressourcen (z. B. `Patient/...`) tatsächlich existieren, prüft er bei einer einzelnen Ressource ebenfalls nicht. Das hat in [Exercise 3](exercise-3.md) Blaze beim Upload übernommen.

### Welcher Validator für welchen Zweck?

Es gibt nicht *den einen* FHIR-Validator. Die meisten Werkzeuge nutzen im Kern denselben HL7-Validator (`validator_cli.jar`) und unterscheiden sich darin, wie man sie aufruft und wie sie vorkonfiguriert sind:

| Werkzeug | Aufruf | Typischer Einsatz | Kennst du aus |
| --- | --- | --- | --- |
| `$validate-code` am Terminologieserver | REST-Anfrage | Einzelnen Code prüfen | [Exercise 5](exercise-5.md) |
| IG Publisher | Build-Prozess | Profile und Beispiele eines eigenen IG prüfen (QA-Report) | [Exercise 1](exercise-1.md) |
| HL7 Validator (`validator_cli.jar`) | Kommandozeile | Beliebige Ressourcen gegen beliebige IGs, z. B. in CI | [Vertiefung](#vertiefung) |
| **MII FHIR Validator** | HTTP: `POST /validateResource` | **Ressourcen gegen die MII-KDS-Profile prüfen** | **diese Übung** |

Im MII-Kontext nutzen wir den [MII FHIR Validator](https://github.com/medizininformatik-initiative/mii-fhir-validator): Er ist der HL7-Validator im Server-Modus, als Docker-Image fertig vorkonfiguriert mit den Paketen der MII-Kerndatensatz-Module. Weitere Validatoren (z. B. Firely, gematik Referenzvalidator) findest du in [Exercise 8](exercise-8.md).

___

## <a id="aufbau"></a>🧩 Aufbau: Drei Server, drei Ports

In dieser Übung arbeiten drei Server zusammen:

```text
                     Ressource (JSON)                    $validate-code, $expand
  curl  ─────────────────────────────────▶  Validator  ─────────────────────────▶  FHIRsmith
   ▲                                       :8082                                   :8081
   │ Ressource holen
   │
 Blaze :8080  (Musterdaten aus Exercise 3)
```

| Server | Port | Aus Übung | Aufgabe |
| --- | --- | --- | --- |
| Blaze | `8080` | [Exercise 2](exercise-2.md) | FHIR-Server mit den Musterdaten |
| FHIRsmith | `8081` | [Exercise 5](exercise-5.md) | Terminologieserver (ICD-10-GM, OPS, Alpha-ID-SE, UCUM …) |
| MII FHIR Validator | `8082` | diese Übung | Prüft Ressourcen gegen Profile, fragt Codes bei FHIRsmith an |

> 💡 **Eigenes Setup mit anderen Adressen?** Laufen einzelne Server bei dir nicht lokal (z. B. auf einem Server im Netz), ersetze `localhost` in den Befehlen durch dessen Adresse und setze `TX_SERVER` in Schritt 1 auf die URL deines Terminologieservers.

___

## <a id="schritt-1"></a>🛠️ Schritt 1: Validator starten

> ⚠️ **Voraussetzung:** Blaze (Port 8080) und FHIRsmith (Port 8081) laufen. Prüfe das kurz:
>
> ```bash
> curl -s http://localhost:8080/fhir/metadata | jq '.software'
> curl -s http://localhost:8081/fhir/metadata | jq '.software'
> ```

Lege einen eigenen Ordner für den Validator an:

```bash
mkdir -p ~/validator
cd ~/validator
```

Lege dort die Datei `docker-compose.yml` an:

> 💡 Alle Dienste der Übungen mit Ports und `docker-compose.yml` findest du gesammelt auf der Seite [Dienste](services.md).


```yaml
services:
  validator:
    image: "ghcr.io/medizininformatik-initiative/mii-fhir-validator:0.0.1-alpha.9"
    environment:
      # Arbeitsspeicher für den Validator (Standard des Images: 16 GB)
      JAVA_OPTS: "-Xmx4g"
      # Terminologieserver aus Exercise 5
      TX_SERVER: "http://host.docker.internal:8081/fhir"
      # Nur die KDS-Pakete laden, die wir für die Musterdaten brauchen
      IG_PARAMS: >-
        -ig de.basisprofil.r4#1.5.4
        -ig de.medizininformatikinitiative.kerndatensatz.meta#2026.0.0
        -ig de.medizininformatikinitiative.kerndatensatz.base#2026.0.1
        -ig de.medizininformatikinitiative.kerndatensatz.laborbefund#2026.0.3
    extra_hosts:
      - "host.docker.internal:host-gateway"
    ports:
      - "8082:8080"
    volumes:
      - fhir-package-cache:/root/.fhir/packages
      - tx-cache:/tmp/tx-cache

volumes:
  fhir-package-cache:
  tx-cache:
```

🔍 **Genau hinschauen:**

- `ports: "8082:8080"`: Im Container lauscht der Validator auf Port 8080. Da Blaze diesen Port auf deinem Rechner schon belegt, machen wir ihn unter **8082** erreichbar.
- `TX_SERVER`: Aus Sicht des Containers ist `localhost` der Container selbst. `host.docker.internal` zeigt dagegen auf deinen Rechner, wo FHIRsmith auf Port 8081 läuft. Die Zeile `extra_hosts` macht diesen Namen auch unter Linux bekannt.
- `IG_PARAMS`: Welche Implementation Guides der Validator lädt. Lässt du die Variable weg, lädt er alle 17 MII-Module. Das braucht aber deutlich mehr Arbeitsspeicher und Startzeit.

> 💡 **Arbeitsspeicher:** Blaze (bis 2 GB), FHIRsmith (bis 4 GB) und Validator (bis 4 GB) brauchen zusammen viel Speicher. Wird es auf deinem Rechner knapp, hole dir zuerst die Ressourcen aus Schritt 2 und 3 als Dateien und stoppe danach Blaze (`docker compose down` im Blaze-Ordner).

Starte den Validator und verfolge den Start im Log:

```bash
docker compose up -d
docker compose logs -f validator
```

Beim Start lädt der Validator die Pakete und baut seine Profile auf. Das dauert einige Minuten. Mit `Strg+C` beendest du die Log-Anzeige; der Validator läuft weiter.

<!-- TODO beim Test: Zeile im Log notieren, an der der Validator bereit ist -->

Prüfe, ob der Validator antwortet, indem du eine minimale Patient-Ressource validierst:

```bash
echo '{"resourceType": "Patient"}' \
  | curl -s -X POST http://localhost:8082/validateResource \
      -H "Content-Type: application/fhir+json" \
      --data @- \
  | jq
```

✅ **Erwartetes Ergebnis:** Ein `OperationOutcome` mit einem `issue` der Schwere `information` (z. B. „All OK“).

<!-- TODO beim Test: tatsächliche Antwort eintragen -->

> 💡 `--data @-` liest die Ressource aus der Pipe statt aus einer Datei. So kannst du Ressourcen direkt aus Blaze an den Validator weiterreichen.

___

## <a id="schritt-2"></a>💻 Schritt 2: Eigene Ressource validieren

Deine HbA1c-Observation aus [Exercise 1](exercise-1.md) liegt seit [Exercise 2](exercise-2.md) in Blaze. Hole sie dir als Datei:

```bash
cd ~/validator
curl -s http://localhost:8080/fhir/Observation/Example-Studie-HbA1c-01 > hba1c.json
jq '.meta.profile' hba1c.json
```

Die Ressource gibt in `meta.profile` dein eigenes Studienprofil an (`http://example.org/StructureDefinition/pr-studie-hba1c`).

### 2.1 Validieren wie angegeben

Ohne weitere Angaben prüft der Validator gegen die Profile aus `meta.profile`:

```bash
curl -s -X POST http://localhost:8082/validateResource \
  -H "Content-Type: application/fhir+json" \
  --data @hba1c.json \
  | jq '[.issue[] | {severity, text: (.details.text // .diagnostics), ort: (.expression // .location)[0]}]'
```

🔍 **Genau hinschauen:** Was meldet der Validator zu deinem Studienprofil? Kennt er es überhaupt?

<!-- TODO beim Test: erwartete Meldungen eintragen (vermutlich: Profil unbekannt, da das ExampleIG nicht geladen ist) -->

### 2.2 Gegen das MII-Laborprofil validieren

Dein Studienprofil erbt von `MII_PR_Labor_Laboruntersuchung`. Dieses Profil kennt der Validator. Mit dem Parameter `profiles` gibst du es beim Aufruf vor:

```bash
curl -s -X POST "http://localhost:8082/validateResource?profiles=https://www.medizininformatik-initiative.de/fhir/core/modul-labor/StructureDefinition/ObservationLab" \
  -H "Content-Type: application/fhir+json" \
  --data @hba1c.json \
  | jq '[.issue[] | {severity, text: (.details.text // .diagnostics), ort: (.expression // .location)[0]}]'
```

<!-- TODO beim Test: erwartete Meldungen eintragen -->

> 💡 **Eigene Profile laden:** Damit der Validator dein Studienprofil selbst kennt, bräuchte er das Paket deines IG. Der IG Publisher erzeugt es in [Exercise 1](exercise-1.md) als `output/package.tgz`. Über `IG_PARAMS` (z. B. `-ig /igs/package.tgz`) und einen eingebundenen Ordner `/igs` kann der Validator es laden. Für diese Übung reicht die Prüfung gegen das MII-Profil.

___

## <a id="schritt-3"></a>💻 Schritt 3: Musterdaten aus Blaze validieren

Jetzt prüfst du echte KDS-Daten. In [Exercise 4](exercise-4.md) sind dir dabei schon Auffälligkeiten begegnet. Was sagt der Validator dazu?

### 3.1 Der seltsame Diagnosecode

```bash
curl -s "http://localhost:8080/fhir/Condition?code=570762" | jq '.entry[0].resource' > condition-570762.json

curl -s -X POST http://localhost:8082/validateResource \
  -H "Content-Type: application/fhir+json" \
  --data @condition-570762.json \
  | jq '[.issue[] | {severity, text: (.details.text // .diagnostics), ort: (.expression // .location)[0]}]'
```

<!-- TODO beim Test: erwartete Meldungen eintragen (erwartet: unbekannter ICD-10-GM-Code, ggf. Hinweis zur Profilversion) -->

### 3.2 Eine gültige Diagnose zum Vergleich

```bash
curl -s "http://localhost:8080/fhir/Condition?code=http://fhir.de/CodeSystem/bfarm/icd-10-gm|C20&_count=1" | jq '.entry[0].resource' > condition-c20.json

curl -s -X POST http://localhost:8082/validateResource \
  -H "Content-Type: application/fhir+json" \
  --data @condition-c20.json \
  | jq '[.issue[] | {severity, text: (.details.text // .diagnostics), ort: (.expression // .location)[0]}]'
```

🔍 **Genau hinschauen:** Vergleiche `meta.profile` der Ressource (`jq '.meta.profile' condition-c20.json`) mit den Paketen, die der Validator geladen hat (`IG_PARAMS`). Die Musterdaten wurden 2025 erzeugt und nennen Profilversionen wie `|2025.0.0`. Der Validator kennt die Version 2026. Wie geht er damit um?

<!-- TODO beim Test: Verhalten bei abweichender Profilversion beschreiben -->

### 3.3 Ein Laborwert

```bash
curl -s "http://localhost:8080/fhir/Observation?code=http://loinc.org|718-7&_count=1" | jq '.entry[0].resource' > hb.json

curl -s -X POST http://localhost:8082/validateResource \
  -H "Content-Type: application/fhir+json" \
  --data @hb.json \
  | jq '[.issue[] | {severity, text: (.details.text // .diagnostics), ort: (.expression // .location)[0]}]'
```

🔍 **Genau hinschauen:** Der Laborwert ist mit LOINC kodiert. Hast du LOINC in [Exercise 5](exercise-5.md) auf deinen Terminologieserver geladen? Was meldet der Validator deshalb?

<!-- TODO beim Test: erwartete Meldungen eintragen (erwartet: LOINC auf FHIRsmith nicht verfügbar) -->

### 3.4 Anzeigetexte mitprüfen

Standardmäßig ignoriert der Validator, ob das `display` zum Code passt. Mit `displayOption=Check` prüft er auch das. Das ist dieselbe Prüfung, die du in [Exercise 5](exercise-5.md) mit `$validate-code` von Hand gemacht hast:

```bash
curl -s -X POST "http://localhost:8082/validateResource?displayOption=Check" \
  -H "Content-Type: application/fhir+json" \
  --data @condition-c20.json \
  | jq '[.issue[] | {severity, text: (.details.text // .diagnostics)}]'
```

### 🛠️ Aufgabe: Mehrere Diagnosen prüfen

Die folgende Schleife holt die ersten 10 Diagnosen aus Blaze, validiert jede einzeln und zählt die Meldungen je Schwere:

```bash
for id in $(curl -s "http://localhost:8080/fhir/Condition?_count=10" | jq -r '.entry[].resource.id'); do
  curl -s "http://localhost:8080/fhir/Condition/$id" \
    | curl -s -X POST http://localhost:8082/validateResource \
        -H "Content-Type: application/fhir+json" --data @- \
    | jq -c --arg id "${id:0:20}" '{id: $id, meldungen: ([.issue[].severity] | group_by(.) | map({(.[0]): length}) | add)}'
done
```

- Welche Diagnosen haben `error`-Meldungen?
- Sind es bei allen dieselben Meldungen? Lass dir die Texte einer Diagnose mit dem Befehl aus 3.2 ausgeben.

> ⚠️ **Ganze Bundles:** Der Validator kann auch ein komplettes Bundle prüfen. Bei den rund 8.000 Ressourcen aus [Exercise 3](exercise-3.md) dauert das aber sehr lange und braucht viel Speicher. Im DIZ-Alltag validiert man deshalb meist Stichproben oder einzelne Ressourcen direkt in der ETL-Strecke.

Die Berichte aus diesem Schritt wertest du in [Exercise 7](exercise-7.md) genauer aus. Lass die Dateien `hba1c.json`, `condition-570762.json`, `condition-c20.json` und `hb.json` im Ordner `~/validator` liegen.

___

## <a id="vertiefung"></a>🔍 Vertiefung: Validator über die Kommandozeile

Der MII FHIR Validator startet intern den HL7-Validator (`validator_cli.jar`) im Server-Modus. Denselben Validator kannst du auch direkt per Kommandozeile aufrufen, z. B. in einer CI-Pipeline. Java hast du seit [Exercise 1](exercise-1.md) installiert. Die wichtigsten Parameter:

| Parameter | Bedeutung | Entspricht im MII FHIR Validator |
| --- | --- | --- |
| `-version 4.0.1` | FHIR-Version (R4) | `FHIR_VERSION` |
| `-ig <paket>#<version>` | Implementation Guide laden | `IG_PARAMS` |
| `-tx <url>` | Terminologieserver | `TX_SERVER` |
| `-profile <url>` | Gegen dieses Profil prüfen | Query-Parameter `profiles` |

Der Rückgabewert (Exit-Code) des Aufrufs zeigt, ob die Validierung erfolgreich war (laut MII-PRO-IG):

| Exit-Code | Bedeutung |
| --- | --- |
| `0` | Keine Fehler oder Warnungen |
| `1` | Nur Warnungen |
| `2+` | Fehler |

> 💡 Der [IG Publisher](exercise-1.md) aus Exercise 1 nutzt intern ebenfalls diesen Validator. Seinen QA-Report kannst du deshalb mit dem Wissen aus [Exercise 7](exercise-7.md) genauso lesen.

___

## <a id="zusammenfassung"></a>🏁 Zusammenfassung und Ausblick

| Schritt | Befehl |
| --- | --- |
| Validator starten | `cd ~/validator && docker compose up -d` |
| Start verfolgen | `docker compose logs -f validator` |
| Ressource validieren | `curl -s -X POST http://localhost:8082/validateResource -H "Content-Type: application/fhir+json" --data @ressource.json` |
| Gegen ein Profil validieren | `…/validateResource?profiles=<Profil-URL>` |
| Anzeigetexte mitprüfen | `…/validateResource?displayOption=Check` |
| Ressource direkt aus Blaze validieren | `curl -s <Blaze-URL> \| curl -s -X POST …/validateResource -H "…" --data @-` |
| Validator stoppen | `cd ~/validator && docker compose down` |

**Was du mitnehmen sollst:**

- Ein Validator prüft Ressourcen gegen **Profile**. Welche Profile er kennt, bestimmen die geladenen IG-Pakete.
- Alle Code-Prüfungen gibt er an den **Terminologieserver** weiter. Was dort nicht geladen ist, kann er nicht prüfen.
- Profile haben **Versionen**. Daten, die gegen eine ältere Version erzeugt wurden, prüft man nicht automatisch gegen die richtige.

**Ausblick:**

- [Exercise 7](exercise-7.md): Validierungsberichte lesen, filtern und Meldungen einordnen
- [Exercise 8](exercise-8.md): Alternative Validatoren, Versionierung und Lizenzen von Codesystemen

___
___
[Prerequisites](prerequisites.md) • [Dienste](services.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • **Exercise 6** • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
___
___
