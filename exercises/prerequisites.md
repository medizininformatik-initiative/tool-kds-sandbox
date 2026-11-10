___
___
**Voraussetzungen** • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___

# ⚪ Voraussetzungen

Bevor du mit den Übungen startest, stelle sicher, dass deine Umgebung die folgenden Voraussetzungen erfüllt. Die genaue Installation der Werkzeuge erklären die jeweiligen Übungen.

___

## 💻 Technische Mindestanforderungen

- **Betriebssystem:** Linux (z. B. Ubuntu/Debian) oder Windows mit **WSL2**
- **Arbeitsspeicher:** mindestens **8 GB**, empfohlen **16 GB**. Ab [Übung 6 · Ressourcen validieren](exercise-6.md) laufen FHIR-Server, Terminologieserver und Validator gleichzeitig und brauchen zusammen bis zu 10 GB.
- **Rechte:** Sudo-Rechte, um Pakete zu installieren
- **Internet:** für Paketinstallationen, Docker-Images und FHIR-Pakete

___

## 🛠️ Benötigte Werkzeuge

| Werkzeug | Wofür | Ab Übung | Installation |
| --- | --- | --- | --- |
| `git`, `curl`, `jq`, `unzip` | Repositories klonen, Server abfragen, JSON auswerten, Musterdaten entpacken | 1 | Befehl unten |
| Node.js mit `npm`, `sushi` | FSH-Profile kompilieren | 1 | [Übung 1 · Profil erstellen](exercise-1.md) |
| .NET und Firely Terminal | FHIR-Pakete verwalten | 1 | [Übung 1 · Profil erstellen](exercise-1.md) |
| Java (empfohlen 17 oder 21) und Jekyll | IG Publisher | 1 | [Übung 1 · Profil erstellen](exercise-1.md) |
| Docker und Docker Compose | FHIR-Server, Terminologieserver, Validator | 2 | [Übung 2 · FHIR-Server starten](exercise-2.md) |
| Python 3 oder R | Skriptbasierte Auswertung (optional) | 4 | [Übung 4 · Daten abfragen](exercise-4.md) |

Die Basiswerkzeuge der ersten Zeile installierst du unter Ubuntu/Debian (auch WSL2) so:

```bash
sudo apt update && sudo apt install -y git curl jq unzip
```

Klone danach dieses Repository in dein Home-Verzeichnis. Mehrere Übungen rufen Skripte unter `~/tool-kds-sandbox` auf:

```bash
cd ~
git clone https://github.com/medizininformatik-initiative/tool-kds-sandbox.git
```

Sobald alles eingerichtet ist, kannst du die Installation prüfen:

```bash
git --version
jq --version
sushi --version
java -version
docker compose version
```

___

## 🧩 Benötigte Dienste

Ab [Übung 2 · FHIR-Server starten](exercise-2.md) startest du bis zu drei Dienste als Docker-Container. Sie bauen aufeinander auf und laufen auf festen Ports. In [Übung 5 · Codes prüfen](exercise-5.md) nutzt du zusätzlich den öffentlichen Terminologieserver tx.fhir.org, ganz ohne Installation.

| Dienst | Port | Ab Übung |
| --- | --- | --- |
| FHIR-Server **Blaze** | `8080` | [Übung 2 · FHIR-Server starten](exercise-2.md) |
| Terminologieserver **FHIRsmith** | `8081` | [Übung 6 · Ressourcen validieren](exercise-6.md) |
| **MII FHIR Validator** | `8082` | [Übung 6 · Ressourcen validieren](exercise-6.md) |

Die Übungen leiten dich Schritt für Schritt durch das Aufsetzen. Alle `docker-compose.yml`-Dateien, Start- und Prüfbefehle findest du zusätzlich gesammelt auf der Seite **[Dienste](services.md)**.

___

## 💡 Hinweis zu den Übungsmaterialien & Lösungen

Bearbeite die Übungen am besten selbstständig in deinem lokalen `main`-Branch.

Die Musterlösungen der einzelnen Übungen (z. B. FSH-Dateien, Skripte) liegen im Repository in den Ordnern `solution-exercise-1`, `solution-exercise-2` usw. Einige Übungen rufen Skripte aus diesen Ordnern direkt auf.

___
___
**Voraussetzungen** • [Dienste](services.md) • [1 · Profil erstellen](exercise-1.md) • [2 · FHIR-Server starten](exercise-2.md) • [3 · Musterdaten laden](exercise-3.md) • [4 · Daten abfragen](exercise-4.md) • [5 · Codes prüfen](exercise-5.md) • [6 · Ressourcen validieren](exercise-6.md) • [7 · Berichte auswerten](exercise-7.md)
___
___
