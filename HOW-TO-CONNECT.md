# LernSpiel - Verbindungsanleitung (How to Connect)

## Server-Adresse

Die Plattform ist erreichbar unter:

- **Extern (via Cloudflare Tunnel):** `https://srl.infotore.cc`
- **Lokal (im selben Netzwerk):** `http://<Mac-Mini-IP>:8090`

---

## Alle verfuegbaren Seiten

### Hauptseiten

| Seite | URL | Beschreibung |
|-------|-----|--------------|
| **Login / Start** | `/` oder `/index.html` | Schueler-Login (Vorname + Klasse) |
| **Hub** | `/hub.html` | Hauptmenue nach dem Login -- Zugang zu allen Spielen und Funktionen |
| **Lernraum** | `/lernraum.html` | Lernraum Check-in/Checkout System |
| **Beitreten (Join)** | `/join.html` | Einer Sitzung per Code beitreten |

### Admin-Bereich

| Seite | URL | Beschreibung |
|-------|-----|--------------|
| **Admin Dashboard** | `/admin/index.html` | Verwaltung: Schueler, Spiele, Klassen, Chat, PDFs, Statistiken |

### Lehrer-Bereich

| Seite | URL | Beschreibung |
|-------|-----|--------------|
| **Vokabel-Upload** | `/teacher/vocab-upload.html` | Vokabeln hochladen und verwalten |

### Spiele

| Spiel | URL | Beschreibung |
|-------|-----|--------------|
| **Vokabel-Quiz** | `/games/vocab-quiz.html` | Multiple-Choice Vokabelabfrage |
| **Vokabel-SRS** | `/games/vocab-srs.html` | Spaced Repetition (Leitner-System) |
| **Satz-Baukasten** | `/games/sentence-builder.html` | Saetze aus Woertern zusammenbauen |
| **Lueckentext** | `/games/fill-blank.html` | Fehlende Woerter einsetzen |
| **Wort markieren** | `/games/mark-word.html` | Richtige Woerter im Text markieren |
| **Geschichte vervollstaendigen** | `/games/complete-story.html` | Geschichte zu Ende schreiben |
| **Memory** | `/games/memory-match.html` | Paare finden (Memory-Spiel) |
| **Kategorien sortieren** | `/games/category-sort.html` | Woerter in Kategorien einordnen |
| **Speed Round** | `/games/speed-round.html` | Schnellrunde -- so viele richtige Antworten wie moeglich |

---

## Schritt-fuer-Schritt: Als Schueler verbinden

1. **Browser oeffnen** und `https://srl.infotore.cc` aufrufen
2. Auf der **Login-Seite** (`/index.html`) **Vorname** und **Klasse** eingeben
3. Auf **"Anmelden"** klicken
4. Du landest im **Hub** (`/hub.html`) -- von dort aus kannst du:
   - Spiele starten
   - Den Lernraum betreten
   - Vokabeln ueben
   - Persoenliche Aufgaben sehen

---

## Schritt-fuer-Schritt: Als Lehrer / Admin verbinden

1. **Browser oeffnen** und `https://srl.infotore.cc/admin/index.html` aufrufen
2. Mit den **Admin-Zugangsdaten** anmelden
3. Im Admin-Dashboard kannst du:
   - Schueler und Klassen verwalten
   - Spiele erstellen und zuweisen
   - Lesson-Codes generieren (QR-Codes fuer Anwesenheit)
   - Chat-Nachrichten lesen
   - PDFs hochladen/verwalten
   - AI-Feedback einsehen
4. Zum **Vokabel-Upload**: `/teacher/vocab-upload.html`

---

## Schritt-fuer-Schritt: Lernraum Check-in

1. `https://srl.infotore.cc/lernraum.html` aufrufen
2. Den angezeigten **Lesson-Code** eingeben (oder QR-Code scannen)
3. Check-in wird registriert
4. Beim Verlassen: **Checkout** nicht vergessen

---

## Fehlerbehebung

| Problem | Loesung |
|---------|---------|
| Seite laedt nicht | Pruefen ob Server laeuft: `lsof -ti:8090` |
| Nur `/lernraum.html` erreichbar | Versuche `/index.html` -- der Login ist der Haupteinstiegspunkt |
| Cloudflare-Fehler | Cloudflare Tunnel pruefen: `launchctl list \| grep cloudflare` |
| Spiel startet nicht | Sicherstellen, dass du eingeloggt bist (ueber `/index.html`) |

---

## Server neu starten (fuer Admins)

```bash
# Laufenden Server stoppen
kill $(lsof -ti:8090)

# Neu bauen und starten
cd /Users/thomasrenne/Plattform-SRL
swift build && swift run App serve --hostname 0.0.0.0 --port 8090
```
