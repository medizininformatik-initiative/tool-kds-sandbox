___
___
**Prerequisites** • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___

# ⚪ Prerequisites

Bevor du mit den Übungen startest, stelle sicher, dass deine lokale Entwicklungsumgebung die folgenden Voraussetzungen erfüllt. Das spart Zeit und verhindert Frustration bei den späteren Validierungs- und Build-Schritten.

## 💻 Technische Mindestanforderungen

* **Betriebssystem:** Linux (bspw. Ubuntu/Debian) oder Windows mit **WSL2** (Windows Subsystem for Linux).
* **Hardware:** Mindestens **8 GB Arbeitsspeicher (RAM)**. Der FHIR-Publisher und der lokale Validierungsservice benötigen temporär viel Speicher.
* **Rechte:** Du benötigst **Sudo-Rechte** auf dem System, um Pakete (wie Docker, Java, Node.js) zu installieren.

---

## 🛠️ Benötigte Werkzeuge (Installations-Checkliste)

Die Übungen bauen aufeinander auf. Du wirst im Laufe des Tutorials folgende Tools einrichten (die genaue Anleitung erfolgt in den jeweiligen Übungen):

1. **Für die Modellierung (Exercise 0):** Node.js mit `npm`, der Compiler `sushi` sowie das `Firely Terminal`.
2. **Für das HTML-Rendering (Exercise 0):** Eine aktuelle **Java-Umgebung** (mindestens Java 11, empfohlen Java 17 oder 21) sowie **Jekyll**, um die Weboberfläche deines Leitfadens lokal zu generieren.
3. **Für die Infrastruktur (Exercise 1–5):** `Docker` und `Docker-Compose` zum Starten des lokalen FHIR-Servers (`blaze`), des Terminologieservers und des MII-Validators.

## 💡 **Hinweis zu den Übungsmaterialien & Lösungen:**

> Bearbeite die Übungen am Besten selbstständig in deinem lokalen Main-Branch.

Alle Ordnerstrukturen, Konfigurationsdateien (wie `docker-compose.yml`) und fertigen FSH-Beispieldateien der einzelnen Übungen sind im Git-Repository über separate Branches organisiert. Die Beispieldateien bzw. Musterlösungen stehen dir jeweils im passenden Solution-Branch (z. B. `solution_exercise-0`, `solution_exercise-1` etc.) zur Verfügung.

___

## Copy-Pasta (später entfernen)

💡 Leuchtende Glühbirne (Fokus & Wichtiges, für Tipps, Ideen, Merksätze)  
⚠️ Warnschild / Achtung (für Stolperfallen oder Fehlerquellen)  
❗ Ausrufezeichen (für wichtige Hinweise)  
🔍 Lupe (für Details oder „Genau hinschauen“)
🚀 Rakete (für den Start oder „Schnellkurs“)  
🏁 Zielflagge (für das Endergebnis oder Zwischenziele)  
🛠️ Werkzeug / Hammer & Schraubenschlüssel (für Vorbereitung/Setup)  
🧩 Puzzleteil (für Module oder Zusammenhänge)  
📋 Struktur & Navigation  
📌 Pinnnadel (für Fixpunkte oder Zusammenfassungen)  
📖 Offenes Buch (für Theorie-Grundlagen)  
💻 Laptop / Computer (für Praxis-Schritte am Bildschirm)  
✅ Grünes Häkchen (für erledigte Schritte oder "Richtig-Beispiele")  
❌ Rotes Kreuz (für "Falsch-Beispiele")  

___
___
**Prerequisites** • [Exercise 0](exercise-0.md) • [Exercise 1](exercise-1.md) • [Exercise 2](exercise-2.md) • [Exercise 3](exercise-3.md) • [Exercise 4](exercise-4.md) • [Exercise 5](exercise-5.md) • [Exercise 6](exercise-6.md) • [Exercise 7](exercise-7.md)
___
___
