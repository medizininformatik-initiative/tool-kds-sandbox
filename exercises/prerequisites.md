___
___
**Prerequisites** • [Dienste](services.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
___
___

# ⚪ Prerequisites

Bevor du mit den Übungen startest, stelle sicher, dass deine Umgebung die folgenden Voraussetzungen erfüllt. Die genaue Installation der Werkzeuge erklären die jeweiligen Übungen.

___

## 💻 Technische Mindestanforderungen

- **Betriebssystem:** Linux (z. B. Ubuntu/Debian) oder Windows mit **WSL2**
- **Arbeitsspeicher:** mindestens **8 GB**, empfohlen **16 GB**. Ab [Exercise 6](exercise-6.md) laufen FHIR-Server, Terminologieserver und Validator gleichzeitig und brauchen zusammen bis zu 10 GB.
- **Rechte:** Sudo-Rechte, um Pakete zu installieren
- **Internet:** für Paketinstallationen, Docker-Images und FHIR-Pakete

___

## 🛠️ Benötigte Werkzeuge

| Werkzeug | Wofür | Ab Übung | Installation |
| --- | --- | --- | --- |
| `git`, `curl`, `jq`, `unzip` | Repositories klonen, Server abfragen, JSON auswerten, Musterdaten entpacken | 1 | Befehl unten |
| Node.js mit `npm`, `sushi` | FSH-Profile kompilieren | 1 | [Exercise 1](exercise-1.md) |
| .NET und Firely Terminal | FHIR-Pakete verwalten | 1 | [Exercise 1](exercise-1.md) |
| Java (empfohlen 17 oder 21) und Jekyll | IG Publisher | 1 | [Exercise 1](exercise-1.md) |
| Docker und Docker Compose | FHIR-Server, Terminologieserver, Validator | 2 | [Exercise 2](exercise-2.md) |
| Python 3 oder R | Skriptbasierte Auswertung (optional) | 4 | [Exercise 4](exercise-4.md) |

Die Basiswerkzeuge der ersten Zeile installierst du unter Ubuntu/Debian (auch WSL2) so:

```bash
sudo apt update && sudo apt install -y git curl jq unzip
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

Ab [Exercise 2](exercise-2.md) startest du drei Dienste als Docker-Container. Sie bauen aufeinander auf und laufen auf festen Ports:

| Dienst | Port | Ab Übung |
| --- | --- | --- |
| FHIR-Server **Blaze** | `8080` | [Exercise 2](exercise-2.md) |
| Terminologieserver **FHIRsmith** | `8081` | [Exercise 5](exercise-5.md) |
| **MII FHIR Validator** | `8082` | [Exercise 6](exercise-6.md) |

Die Übungen leiten dich Schritt für Schritt durch das Aufsetzen. Alle `docker-compose.yml`-Dateien, Start- und Prüfbefehle findest du zusätzlich gesammelt auf der Seite **[Dienste](services.md)**.

___

## 💡 Hinweis zu den Übungsmaterialien & Lösungen

Bearbeite die Übungen am besten selbstständig in deinem lokalen `main`-Branch.

Die Musterlösungen der einzelnen Übungen (z. B. FSH-Dateien, Skripte) stehen dir jeweils im passenden Solution-Branch zur Verfügung (`solution_exercise-1`, `solution_exercise-2` usw.).

___
___
**Prerequisites** • [Dienste](services.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md) • [Exercise 8](exercise-8.md)
___
___
