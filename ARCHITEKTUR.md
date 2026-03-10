# LernSpiel — Architektur-Plan

**Gamification-Plattform für SRL-Lernzeiten**
Version 0.1.0 | Stand: 07.03.2026

---

## 1. Überblick

LernSpiel ist eine modulare Gamification-Plattform, die auf einem Mac Mini im Schulnetzwerk läuft. SuS öffnen die Web-App im Browser (iPad, Android, Laptop) und identifizieren sich über Namenseingabe — wie im bestehenden Lernraum-Check.

```
┌──────────────────────────────────────────────────────────┐
│  SuS-Geräte (Browser)                                     │
│  iPad / Android / Laptop                                  │
└────────────────────┬─────────────────────────────────────┘
                     │ HTTP (REST API) + WebSocket (später)
                     ▼
┌──────────────────────────────────────────────────────────┐
│  Mac Mini (Schulnetz / Heimnetz)                          │
│                                                            │
│  Vapor 4 (Swift)                                          │
│  ├── Static File Middleware → Frontend (HTML/JS/CSS)      │
│  ├── /api/players/*          → Spieler-Verwaltung         │
│  ├── /api/games/*            → Spiel-Module + Sessions    │
│  └── /api/scores/*           → Fortschritt + Leaderboard  │
│                                                            │
│  SQLite (lernspiel.sqlite)                                │
│  → Upgrade-Pfad: PostgreSQL via Fluent ORM               │
└──────────────────────────────────────────────────────────┘
```

---

## 2. Datenmodell

### Player (Spieler = SuS)
| Feld | Typ | Beschreibung |
|------|-----|-------------|
| id | UUID | Primary Key |
| name | String | Vorname (Eingabe wie Lernraum-Check) |
| klasse | String | z.B. "BFW1", "1BFR2" |
| created_at | Date | Erstregistrierung |
| last_seen | Date | Letzter Login |

**Identifikation:** Name + Klasse = eindeutig. Kein Passwort.

### GameModule (Spieltyp-Definition)
| Feld | Typ | Beschreibung |
|------|-----|-------------|
| id | UUID | Primary Key |
| type | String | "vocab-quiz", "grammar-drag", "fill-blank" |
| title | String | Anzeige-Name |
| kompetenz | String? | z.B. "Leseverstehen" |
| ls_number | Int? | 1-6 (Lernstufe) |
| solo_level | String? | "uni", "multi", "rel", "ext" |
| config | JSON | Spieltyp-spezifische Konfiguration |
| created_at | Date | |

**config-Beispiel (vocab-quiz):**
```json
{
  "questions": [
    {
      "word": "sustainable",
      "correct": "nachhaltig",
      "distractors": ["erreichbar", "haltbar", "verträglich"],
      "example": "We need sustainable energy sources.",
      "timeLimit": 15
    }
  ],
  "settings": {
    "shuffleQuestions": true,
    "showExamples": true,
    "pointsPerCorrect": 10,
    "bonusForSpeed": true
  }
}
```

### GameSession (Einzelne Spiel-Durchführung)
| Feld | Typ | Beschreibung |
|------|-----|-------------|
| id | UUID | Primary Key |
| player_id | UUID → Player | Wer hat gespielt? |
| module_id | UUID → GameModule | Welches Spiel? |
| score | Int | Erreichte Punkte |
| max_score | Int | Maximale Punkte |
| time_spent | Int | Sekunden |
| details | JSON | Antwort-Details pro Frage |
| completed_at | Date | |

---

## 3. API-Endpunkte

### Player
```
POST   /api/players/login     { name, klasse }  → Player (erstellt oder findet)
GET    /api/players/:id       → Player-Profil + Stats
```

### Games
```
GET    /api/games             → Alle verfügbaren Spiele
GET    /api/games/:id         → Spiel-Details + Config
POST   /api/games             → Neues Spiel erstellen (Lehrkraft)
```

### Sessions (Spiel-Durchführungen)
```
POST   /api/sessions          { player_id, module_id, score, ... }  → Score speichern
GET    /api/sessions/player/:id   → Alle Sessions eines Spielers
GET    /api/sessions/module/:id   → Leaderboard für ein Spiel
```

---

## 4. Frontend-Architektur

```
Public/
├── index.html          ← Entry Point (Lernraum-Check → Hub)
│                          Name + Klasse eingeben → Player-Login
│                          Dann: Hub oder Lernraum-Check wählen
├── hub.html            ← Spiel-Hub (zeigt verfügbare Module)
├── teacher.html        ← Lehrkraft-Dashboard
├── games/
│   ├── vocab-quiz.html ← Vokabel-Quiz (MVP)
│   ├── grammar-drag.html  ← (Erweiterung 1)
│   └── fill-blank.html    ← (Erweiterung 2)
├── css/
│   └── style.css       ← Gemeinsames Design (Lernraum-Check Stil)
└── js/
    ├── api.js          ← API-Client (fetch-Wrapper)
    ├── auth.js         ← Player-State (sessionStorage)
    └── vocab-quiz.js   ← Quiz-Logik
```

**Design-Prinzip:** Gleiche Designsprache wie Lernraum-Check (Dark Theme, DM Sans/DM Serif, CSS Custom Properties).

---

## 5. Spielmodul-Architektur (Erweiterbar)

Jedes Spielmodul besteht aus:
1. **HTML-Datei** in `Public/games/` (UI)
2. **JS-Datei** in `Public/js/` (Spiellogik)
3. **JSON-Config** im GameModule (Fragen/Einstellungen)

### Aktuell geplante Module:

| # | Modul | Fragetypen | Priorität |
|---|-------|-----------|-----------|
| 1 | **Vocab Quiz** | Multiple Choice, Zuordnung | MVP |
| 2 | Grammar Drag & Drop | Satzteile ordnen, Lücken füllen | Erweiterung 1 |
| 3 | Fill-in-the-Blank | Tipp-Eingabe, Autocomplete | Erweiterung 2 |
| 4 | Leaderboard + Dashboard | Fortschritts-Ansicht | Erweiterung 3 |
| 5 | Live-Multiplayer | Klasse vs. Klasse | Erweiterung 4 |
| 6 | Cowork-Generator | AB-Inhalte → Spiel-Config | Erweiterung 5 |

### Neues Modul hinzufügen:
1. HTML + JS in `Public/games/` + `Public/js/`
2. Config-Schema dokumentieren
3. GameModule mit `type` + `config` in DB anlegen
4. Hub zeigt es automatisch an

---

## 6. SRL-Integration

Jedes GameModule kann optional SRL-Metadaten tragen:
- `kompetenz` → Welche Bildungsplan-Kompetenz?
- `ls_number` → Welche Lernstufe (1-6)?
- `solo_level` → SOLO-Taxonomie-Level?
- `ki_ampel` → KI-Nutzung im Spiel?

Dadurch kann die Lehrkraft im Dashboard sehen:
- "Klasse BFW1 hat Vokabeln für LS 3 (Leseverstehen) durchschnittlich zu 78% richtig."
- "SuS X hat Schwächen bei Relational-Level Aufgaben."

---

## 7. Deployment auf Mac Mini

### Voraussetzungen
- macOS 13+ (Ventura oder neuer)
- Xcode 15+ (für Swift Toolchain)
- Homebrew

### Setup
```bash
# 1. Repository klonen/kopieren
cd ~/LernSpiel

# 2. Dependencies laden + bauen
swift build

# 3. Server starten
swift run App serve --hostname 0.0.0.0 --port 8090

# 4. Im Browser öffnen
# http://[mac-mini-ip]:8090
```

### Autostart (launchd)
Für automatischen Start beim Hochfahren → `launchd` plist erstellen.

---

## 8. Upgrade-Pfade

| Von | Nach | Aufwand |
|-----|------|---------|
| SQLite | PostgreSQL | Config ändern, `brew install postgresql` |
| Web-App | Native iOS-Wrapper | WKWebView-Shell, gleiche URL |
| Namenseingabe | QR-Code-Login | QR enthält Player-UUID |
| Einzelspieler | Multiplayer | WebSocket-Controller hinzufügen |
| Manuell Fragen | Cowork-Generator | Skill erstellen, API-Call |

---

**Version:** 0.1.0 | **Stand:** 07.03.2026
