# LernSpiel — Projektdokumentation

> Dokumentation des Planungsprozesses und der Architektur-Entscheidungen.
> Stand: 08.03.2026

---

## 1. Projektüberblick

### Was ist LernSpiel?

Eine webbasierte Gamification-Plattform für selbstreguliertes Lernen (SRL), gehostet auf einem heimischen Mac Mini und online erreichbar via Cloudflare Tunnel.

### Zielgruppe
- **Lernende:** Schüler/innen (SuS) an beruflichen Schulen (BFW, BFR)
- **Lehrkraft:** Erstellt Inhalte, weist Aufgaben zu, überwacht Lernfortschritt
- **Kontext:** SRL-Pilotprojekt — Lernende steuern ihren Lernprozess selbst

### Kernfunktionen
1. **Lernraum-Erfassung** — SuS melden an, wo sie lernen (Kernfunktion für SRL-Pilot)
2. **Spielebereich** — 10 verschiedene Spieltypen für alle SuS (Vokabeln, Grammatik, Textverständnis)
3. **Vokabeltrainer (SRS)** — Evidenzbasiertes Spaced Repetition System (SM-2/Leitner)
4. **Personalisierte Aufgaben** — Individuelle Übungen pro Lernende/r
5. **Online-Zugang** — Erreichbar von überall via HTTPS (Cloudflare Tunnel)

---

## 2. Technologie-Stack

### Warum Swift/Vapor?

Die Plattform wurde mit Swift/Vapor gebaut, weil:
- Der Mac Mini macOS läuft und Swift die native Sprache ist
- Vapor ein ausgereiftes, async/await-basiertes Web-Framework ist
- Fluent ORM typsichere Datenbankabfragen ermöglicht
- SQLite als Datenbank einfach zu betreiben und zu sichern ist (eine Datei)

**Ehrliche Einschätzung:** Swift/Vapor ist eine Nischen-Wahl für Web-Apps. Node.js oder Python hätten ein größeres Ökosystem und offizielle Claude-SDKs. Da der Code aber steht und sauber funktioniert, wurde entschieden, darauf aufzubauen statt umzuschreiben.

### Warum Vanilla JS?

- Kein Build-Step nötig (kein Webpack, kein npm)
- Einfach zu verstehen und zu warten
- Schnell — keine Framework-Overhead
- Für die Komplexität dieser App ausreichend
- Funktioniert auf allen Geräten ohne Polyfills

### Vollständiger Stack

| Komponente | Technologie | Version |
|------------|------------|---------|
| Backend | Swift + Vapor | 5.9 / 4.89+ |
| ORM | Fluent | 4.8+ |
| Datenbank | SQLite | via FluentSQLiteDriver |
| Frontend | HTML5 + CSS3 + Vanilla JS | ES6 |
| Hosting | Mac Mini (macOS 13+) | Heimnetzwerk |
| Tunnel | Cloudflare Tunnel | cloudflared |
| Design | Dark Theme | DM Sans / DM Serif Display |

---

## 3. Architektur

### Verzeichnisstruktur

```
LernSpiel/
├── Package.swift                     # Swift-Dependencies
├── Sources/App/
│   ├── entrypoint.swift              # Server-Einstiegspunkt
│   ├── configure.swift               # DB, Middleware, Migrations
│   ├── routes.swift                  # Controller-Registrierung
│   ├── Controllers/
│   │   ├── PlayerController.swift    # Login, Stats
│   │   ├── GameController.swift      # Spiele, Sessions, Leaderboards
│   │   ├── LernraumController.swift  # Check-in/out, Übersicht
│   │   ├── VocabController.swift     # SRS, Import, Review
│   │   └── PersonalTaskController.swift  # Personalisierte Aufgaben
│   ├── Models/
│   │   ├── Player.swift
│   │   ├── GameModule.swift          # Spiel-Definition + Config
│   │   ├── GameSession.swift         # Spiel-Ergebnis
│   │   ├── LernraumCheckin.swift     # Raum-Check-in
│   │   ├── VocabItem.swift           # Vokabel-Eintrag
│   │   ├── VocabProgress.swift       # SRS-Fortschritt pro Lernende/r
│   │   └── PersonalTask.swift        # Individuelle Aufgabe
│   ├── DTOs/
│   │   └── GameDTOs.swift            # Request/Response-Strukturen
│   └── Migrations/
│       ├── CreateInitialTables.swift  # Players, GameModules, GameSessions
│       ├── CreateLernraumCheckin.swift
│       ├── CreateVocabTables.swift
│       └── CreatePersonalTask.swift
└── Public/
    ├── index.html                    # Login
    ├── lernraum.html                 # Raumauswahl
    ├── hub.html                      # Dashboard
    ├── games/
    │   ├── vocab-quiz.html           # Multiple Choice
    │   ├── vocab-srs.html            # Karteikarten (SRS)
    │   ├── sentence-builder.html     # Drag & Drop Satzbau
    │   ├── fill-blank.html           # Lückentext
    │   ├── mark-word.html            # Wörter markieren
    │   ├── complete-story.html       # Geschichte vervollständigen
    │   ├── memory-match.html         # Memory
    │   ├── category-sort.html        # Kategorien zuordnen
    │   ├── speed-round.html          # Schnellrunde
    │   ├── word-search.html          # Wortsuchgitter
    │   └── hangman.html              # Galgenraten
    ├── teacher/
    │   └── vocab-upload.html         # Vokabel-Import
    ├── js/
    │   ├── api.js                    # REST-API Client
    │   ├── auth.js                   # Session-Management
    │   └── game-engine.js            # Gemeinsame Spiel-Engine
    └── css/
        └── style.css                 # Design System
```

### Datenbank-Schema

```
players ──────────────── game_sessions ──────────── game_modules
  id (UUID)                 id (UUID)                  id (UUID)
  name                      player_id (FK)             type
  klasse                    module_id (FK)             title
  last_seen                 score, max_score           config (JSON)
                            time_spent                 kompetenz
                            details (JSON)             ls_number
                                                       solo_level

players ──────────────── lernraum_checkins
                            id (UUID)
                            player_id (FK)
                            raum
                            checked_in_at
                            checked_out_at

players ──────────────── vocab_progress ──────────── vocab_items
                            id (UUID)                  id (UUID)
                            player_id (FK)             english
                            vocab_id (FK)              german
                            box (1-5)                  example_sentence
                            ease_factor                topic
                            interval_days              difficulty
                            next_review
                            repetitions

players ──────────────── personal_tasks
                            id (UUID)
                            player_id (FK)
                            title, type
                            config (JSON)
                            completed
```

### API-Übersicht

| Bereich | Endpoints | Zweck |
|---------|-----------|-------|
| Players | `POST /api/players/login`, `GET .../stats` | Login, Statistiken |
| Games | `GET /api/games`, `POST /api/games` | Spiele auflisten/erstellen |
| Sessions | `POST /api/sessions`, `GET .../leaderboard` | Ergebnisse, Bestenlisten |
| Lernraum | `POST /api/lernraum/checkin`, `GET .../aktiv` | Raum-Tracking |
| Vocab | `POST /api/vocab/import`, `GET .../due/:id` | SRS-System |
| Personal | `POST /api/personal/assign`, `GET .../:id` | Individuelle Aufgaben |

---

## 4. Benutzer-Flow

```
SuS öffnet URL → Login (Name + Klasse)
    → Lernraum wählen (Klassenzimmer / Pausenhof / Arbeitsraum / Anderer)
        → Hub (Dashboard)
            ├── 📍 Aktueller Raum (wechselbar)
            ├── 📊 Statistiken (Spiele, Punkte, Durchschnitt)
            ├── 📋 Deine Aufgaben (personalisiert, falls vorhanden)
            ├── 📚 Vokabeltrainer (fällige Karten)
            └── 🎮 Spielebereich
                ├── Vocab Quiz, Memory, Speed Round...
                └── → Spielen → Ergebnis → Leaderboard → Zurück zum Hub
```

---

## 5. Entscheidungen & Begründungen

### Login ohne Passwort
**Entscheidung:** Nur Name + Klasse, kein Passwort.
**Begründung:** Wie beim bestehenden Lernraum-Check. Minimaler Aufwand für SuS, keine vergessenen Passwörter, ausreichend für Schulkontext.

### SQLite statt PostgreSQL
**Entscheidung:** SQLite als Datenbank.
**Begründung:** Eine Datei, einfaches Backup, keine Installation nötig. Upgrade auf PostgreSQL jederzeit möglich (nur Config-Änderung).

### Cloudflare Tunnel statt VPS
**Entscheidung:** Mac Mini zu Hause + Cloudflare Tunnel statt Cloud-Hosting.
**Begründung:** Kostenlos, keine Server-Administration, Daten bleiben lokal, HTTPS automatisch, SuS brauchen keine Software.

### Dark Theme
**Entscheidung:** Dunkles Design als Standard.
**Begründung:** Modern, augenschonend, passt zur Gaming-Ästhetik, hebt sich von typischen Schul-Plattformen ab.

### SM-2 für Spaced Repetition
**Entscheidung:** SM-2-Algorithmus (vereinfacht) für den Vokabeltrainer.
**Begründung:** Evidenzbasiert (Pimsleur/Leitner/SuperMemo-Forschung), bewährt in Anki, einfach zu implementieren, personalisiert die Wiederholungsintervalle automatisch.

### Erweiterbare Game Engine
**Entscheidung:** Gemeinsame `game-engine.js` statt individueller Spiel-Implementierungen.
**Begründung:** Neues Spiel = nur spezifische Logik definieren. Timer, Scoring, Leaderboard, Feedback kommen von der Engine. Spart Code und gewährleistet einheitliche UX.

### Manuelle Claude-Integration (vorerst)
**Entscheidung:** Lehrkraft erstellt Übungen mit Claude.ai und trägt sie per API ein.
**Begründung:** Realistischer für den Pilotstart. Direkte API-Integration in Phase 2.

### Cowork-Skill statt MCP-Server (vorerst)
**Entscheidung:** Referenz-Dokument (COWORK-SKILL.md) statt vollständiger MCP-Server.
**Begründung:** Sofort nutzbar, kein zusätzlicher Server nötig. Claude Code kann curl-Befehle direkt ausführen. MCP-Server als Upgrade-Pfad für später.

---

## 6. Implementierungsphasen

| Phase | Feature | Abhängigkeiten |
|-------|---------|---------------|
| 1 | Lernraum-Erfassung | Keine — Kernfunktion |
| 2 | Game Engine + 9 neue Spieltypen | Phase 1 (Hub muss stehen) |
| 3 | Vokabeltrainer (SRS) + Upload | Phase 2 (Engine nutzen) |
| 4 | Personalisierte Aufgaben | Phase 2 (Spiel-Engines nutzen) |
| 5 | Cloudflare Tunnel | Unabhängig — kann parallel |

---

## 7. Deployment & Betrieb

### Server starten
```bash
cd ~/LernSpiel
swift build -c release
swift run App serve --hostname 0.0.0.0 --port 8080
```

### Cloudflare Tunnel
```bash
cloudflared tunnel run lernspiel
```

### Backup
```bash
cp ~/LernSpiel/lernspiel.sqlite ~/LernSpiel/backups/lernspiel_$(date +%Y%m%d).sqlite
```

### Autostart (LaunchAgent)
Beide Dienste (Vapor-Server + Cloudflare Tunnel) als LaunchAgents konfigurieren — starten automatisch beim Mac-Mini-Boot.

---

## 8. Zukunftsplanung

- **Lehrkraft-Dashboard** — Web-UI zum Verwalten (Spiele erstellen, Aufgaben zuweisen, Live-Übersicht)
- **Claude-API-Integration** — Automatische Übungsgenerierung basierend auf Fehleranalyse
- **MCP-Server** — Direkte Cowork-Integration für nahtlosen Content-Upload
- **WebSocket/Live-Updates** — Echtzeit-Lernraum-Übersicht für Lehrkraft
- **Export/Reporting** — Lernfortschritt als PDF/CSV exportieren
- **Multiplayer-Modus** — Synchrone Quiz-Battles zwischen SuS
