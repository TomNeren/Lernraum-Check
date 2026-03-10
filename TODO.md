# LernSpiel — Implementierungs-TODO

> **Für Claude auf dem Mac Mini:** Diese Datei beschreibt alle Erweiterungen, die an der LernSpiel-Plattform vorgenommen werden müssen. Arbeite die Phasen der Reihe nach ab. Lies zuerst den bestehenden Code (alle Dateien in Sources/App/ und Public/), um die Patterns zu verstehen, bevor du neue Dateien erstellst.

## Bestehende Architektur (nicht ändern, darauf aufbauen)

- **Backend:** Swift 5.9 + Vapor 4 + Fluent ORM + SQLite
- **Frontend:** Vanilla HTML/CSS/JS, Dark Theme, Mobile-first
- **Datenbank:** `lernspiel.sqlite` mit 3 Tabellen (players, game_modules, game_sessions)
- **API-Pattern:** RouteCollection-Controller mit `@Sendable` async Funktionen
- **Models:** Fluent Models mit `@unchecked Sendable`, `Content` Protocol
- **DTOs:** Separate Structs mit `Content` Protocol in `GameDTOs.swift`
- **Frontend-API:** `Public/js/api.js` wrappet alle Fetch-Calls
- **Auth:** `Public/js/auth.js` mit sessionStorage

---

## PHASE 1: Lernraum-Erfassung ⭐ (PRIORITÄT — muss zuerst laufen)

### 1.1 Neues Model: LernraumCheckin

**Datei erstellen:** `Sources/App/Models/LernraumCheckin.swift`

```swift
import Fluent
import Vapor

final class LernraumCheckin: Model, Content, @unchecked Sendable {
    static let schema = "lernraum_checkins"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "player_id")
    var player: Player

    @Field(key: "raum")
    var raum: String

    @Field(key: "checked_in_at")
    var checkedInAt: Date

    @OptionalField(key: "checked_out_at")
    var checkedOutAt: Date?

    init() {}

    init(id: UUID? = nil, playerID: UUID, raum: String) {
        self.id = id
        self.$player.id = playerID
        self.raum = raum
        self.checkedInAt = Date()
    }
}
```

### 1.2 Neue Migration

**Datei erstellen:** `Sources/App/Migrations/CreateLernraumCheckin.swift`

```swift
import Fluent

struct CreateLernraumCheckin: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("lernraum_checkins")
            .id()
            .field("player_id", .uuid, .required, .references("players", "id"))
            .field("raum", .string, .required)
            .field("checked_in_at", .datetime, .required)
            .field("checked_out_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("lernraum_checkins").delete()
    }
}
```

### 1.3 Neuer Controller: LernraumController

**Datei erstellen:** `Sources/App/Controllers/LernraumController.swift`

Endpoints:
- `POST /api/lernraum/checkin` — Body: `{playerID: UUID, raum: String}`. Prüft ob bereits aktiver Check-in existiert (checked_out_at == nil). Falls ja, erst auschecken (checked_out_at setzen), dann neuen erstellen.
- `PUT /api/lernraum/update` — Body: `{playerID: UUID, raum: String}`. Aktuellen Check-in schließen, neuen mit neuem Raum öffnen.
- `POST /api/lernraum/checkout` — Body: `{playerID: UUID}`. Aktiven Check-in finden und checked_out_at = Date() setzen.
- `GET /api/lernraum/aktiv` — Alle Check-ins wo checked_out_at == nil. Mit Player eager-loaded. Für Lehrkraft-Übersicht.
- `GET /api/lernraum/aktiv/:klasse` — Wie oben, aber gefiltert nach Klasse.
- `GET /api/lernraum/history/:playerID` — Alle Check-ins eines Spielers, sortiert nach checkedInAt descending, limit 50.

DTOs (in `GameDTOs.swift` hinzufügen):
```swift
struct CheckinRequest: Content {
    var playerID: UUID
    var raum: String
}

struct CheckoutRequest: Content {
    var playerID: UUID
}

struct AktivCheckin: Content {
    var id: UUID
    var playerName: String
    var klasse: String
    var raum: String
    var checkedInAt: Date
}
```

### 1.4 configure.swift anpassen

Migration hinzufügen (nach den bestehenden 3):
```swift
app.migrations.add(CreateLernraumCheckin())
```

### 1.5 routes.swift anpassen

Controller registrieren:
```swift
try app.register(collection: LernraumController())
```

### 1.6 Frontend: lernraum.html erstellen

**Datei erstellen:** `Public/lernraum.html`

- Gleiches Design wie index.html (Dark Theme, DM Sans)
- Überschrift: "Wo lernst du heute?"
- 3 große Buttons nebeneinander (Cards): **Klassenzimmer**, **Pausenhof**, **Arbeitsraum**
- Darunter: Input-Feld "Anderer Ort" + "Bestätigen"-Button
- Bei Klick: `POST /api/lernraum/checkin` → Raum in sessionStorage speichern → Redirect zu hub.html
- Requires login (Auth.requireLogin())

### 1.7 Frontend: api.js erweitern

Neue Methoden in `API` Objekt:
```javascript
async checkinLernraum(playerID, raum) { ... }
async updateLernraum(playerID, raum) { ... }
async checkoutLernraum(playerID) { ... }
async getAktiveLernraeume() { ... }
async getAktiveLernraeumeKlasse(klasse) { ... }
async getLernraumHistory(playerID) { ... }
```

### 1.8 Frontend: auth.js erweitern

Neue Methoden:
```javascript
Auth.setRaum(raum)    // sessionStorage.setItem('currentRaum', raum)
Auth.getRaum()        // sessionStorage.getItem('currentRaum')
```

### 1.9 Frontend: index.html anpassen

Nach erfolgreichem Login: Redirect zu `lernraum.html` statt `hub.html`.

### 1.10 Frontend: hub.html anpassen

- Oben: Badge/Info-Box mit aktuellem Raum anzeigen: "📍 Klassenzimmer"
- "Raum wechseln"-Button → leitet zu lernraum.html weiter
- Beim Laden: Raum aus sessionStorage lesen und anzeigen

### 1.11 Testen

```bash
swift build && swift run App serve --hostname 0.0.0.0 --port 8080
```

Test-Flow:
1. http://localhost:8080 → Login
2. → Lernraum-Auswahl → "Klassenzimmer" klicken
3. → Hub zeigt "📍 Klassenzimmer"
4. "Raum wechseln" → "Pausenhof" wählen → Hub aktualisiert

API-Test:
```bash
curl http://localhost:8080/api/lernraum/aktiv
```

---

## PHASE 2: Erweiterbare Game Engine + Neue Spieltypen

### 2.1 Game Engine erstellen

**Datei erstellen:** `Public/js/game-engine.js`

Gemeinsame Basis für alle Spiele. Die Engine stellt bereit:

```javascript
const GameEngine = {
    // State
    currentGame: null,
    score: 0,
    answers: [],
    timerInterval: null,

    // Initialisierung
    async init(gameID) {
        // Game von API laden
        // Auth prüfen
        // Config parsen
        // Spiel-spezifische init() aufrufen
    },

    // Timer
    startTimer(seconds, onTick, onExpire) { ... },
    stopTimer() { ... },

    // Scoring
    addPoints(points) { ... },
    calculateSpeedBonus(timeLeft, maxTime, basePoints) { ... },

    // Feedback
    showFeedback(isCorrect, message) { ... },  // Feedback-Element ein/ausblenden
    showConfetti() { ... },  // CSS-Konfetti bei Quiz-Ende
    shakeElement(el) { ... },  // Shake-Animation bei Fehler

    // Progress
    updateProgress(current, total) { ... },

    // Ergebnis
    async finishGame() {
        // Score an API senden
        // Leaderboard laden
        // Ergebnis-Screen anzeigen
    },

    // Sound (optional, Web Audio API)
    playSound(type) { ... },  // 'correct', 'wrong', 'complete'

    // Registrierung neuer Spieltypen
    types: {},
    register(typeName, handler) {
        this.types[typeName] = handler;
    }
};
```

### 2.2 Vocab-Quiz refactoren

Den bestehenden Code in `vocab-quiz.html` refactoren, sodass er die Game Engine nutzt. Die spiel-spezifische Logik (Multiple-Choice-Buttons, Fragen anzeigen) bleibt, aber Timer, Scoring, Ergebnis-Screen kommen von der Engine.

### 2.3 Sentence Builder (Drag & Drop)

**Datei erstellen:** `Public/games/sentence-builder.html`

- Wörter als "Chips" angezeigt (durcheinander)
- Per Drag & Drop (oder Touch: touchstart/touchmove/touchend) in die richtige Reihenfolge bringen
- Drop-Zone: Horizontale Leiste mit Platzhaltern
- Bei korrekter Reihenfolge: grüner Glow, Punkte
- Touch-Support ist KRITISCH (iPad!)

Config-Format (im GameModule.config JSON):
```json
{
    "type": "sentence-builder",
    "sentences": [
        {
            "id": "uuid",
            "words": ["She", "goes", "to", "school", "every", "day"],
            "correct": "She goes to school every day",
            "hint": "Simple Present - 3. Person Singular"
        }
    ],
    "settings": {
        "shuffleQuestions": true,
        "pointsPerCorrect": 10,
        "bonusForSpeed": true,
        "timeLimit": 30
    }
}
```

### 2.4 Fill the Gap

**Datei erstellen:** `Public/games/fill-blank.html`

- Satz mit Lücke (___) anzeigen
- Entweder Freitext-Input ODER Multiple-Choice-Buttons (je nach Config)
- Akzeptiert mehrere korrekte Antworten (case-insensitive trimmed Vergleich)
- Eingabe-Feld hat blinkende Cursor-Animation

Config-Format:
```json
{
    "type": "fill-blank",
    "sentences": [
        {
            "id": "uuid",
            "text": "She ___ to school every day.",
            "correct": ["goes"],
            "options": ["go", "goes", "went", "going"],
            "mode": "choice",
            "hint": "Simple Present"
        }
    ],
    "settings": { ... }
}
```

`mode`: `"choice"` = Multiple-Choice-Buttons, `"type"` = Freitext-Eingabe

### 2.5 Mark the Word

**Datei erstellen:** `Public/games/mark-word.html`

- Text wird angezeigt, jedes Wort ist ein klickbares `<span>`
- Instruktion: z.B. "Markiere alle Verben im Text"
- Klick → Wort wird farbig hervorgehoben (toggle)
- Am Ende: Vergleich markierte vs. korrekte Wörter
- Punkte pro korrekt markiertes Wort, Abzug pro falsch markiertes

Config-Format:
```json
{
    "type": "mark-word",
    "exercises": [
        {
            "id": "uuid",
            "text": "She goes to school and reads many books every day.",
            "targets": ["goes", "reads"],
            "instruction": "Markiere alle Verben im Simple Present.",
            "category": "Verben"
        }
    ],
    "settings": { ... }
}
```

### 2.6 Complete the Story

**Datei erstellen:** `Public/games/complete-story.html`

- Geschichte wird Abschnitt für Abschnitt angezeigt
- Lücken sind inline (entweder Dropdown oder Freitext)
- Am Ende: Gesamte Story zusammenhängend anzeigen mit eingesetzten Wörtern
- Buch-Ästhetik: Serif-Font (DM Serif Display), breiterer Container

Config-Format:
```json
{
    "type": "complete-story",
    "title": "A Day in London",
    "story": [
        {"type": "text", "content": "Yesterday, Sarah "},
        {"type": "gap", "correct": "went", "options": ["went", "go", "goes"]},
        {"type": "text", "content": " to London. She "},
        {"type": "gap", "correct": "visited", "options": ["visited", "visit", "visits"]},
        {"type": "text", "content": " the Tower of London."}
    ],
    "settings": { ... }
}
```

### 2.7 Memory Match

**Datei erstellen:** `Public/games/memory-match.html`

- Grid von verdeckten Karten (4x4 oder 4x3)
- Karte aufdecken → 3D-Flip-CSS-Animation
- Zwei aufgedeckte Karten: Paar gefunden → bleiben offen, sonst zuklappen
- Paare: English ↔ German
- Scoring: Weniger Versuche = mehr Punkte, Zeitbonus

Config-Format:
```json
{
    "type": "memory-match",
    "pairs": [
        {"front": "sustainable", "back": "nachhaltig"},
        {"front": "environment", "back": "Umwelt"}
    ],
    "settings": {
        "gridCols": 4,
        "pointsPerPair": 20,
        "bonusForSpeed": true,
        "timeLimit": 120
    }
}
```

CSS für 3D-Flip:
```css
.memory-card { perspective: 1000px; }
.memory-card-inner { transition: transform 0.6s; transform-style: preserve-3d; }
.memory-card.flipped .memory-card-inner { transform: rotateY(180deg); }
.memory-card-front, .memory-card-back { backface-visibility: hidden; }
.memory-card-back { transform: rotateY(180deg); }
```

### 2.8 Category Sort (Drag & Drop)

**Datei erstellen:** `Public/games/category-sort.html`

- Oben: Wörter als Chips (unsortiert)
- Unten: 2-4 Kategorie-Spalten (z.B. "Nouns", "Verbs", "Adjectives")
- Drag & Drop (Touch-unterstützt) in die richtige Kategorie
- Sofort-Feedback pro Zuordnung oder am Ende

Config-Format:
```json
{
    "type": "category-sort",
    "categories": ["Nouns", "Verbs", "Adjectives"],
    "items": [
        {"word": "house", "category": "Nouns"},
        {"word": "beautiful", "category": "Adjectives"},
        {"word": "run", "category": "Verbs"}
    ],
    "settings": { ... }
}
```

### 2.9 Speed Round

**Datei erstellen:** `Public/games/speed-round.html`

- Wort erscheint groß in der Mitte
- Eingabefeld darunter, Cursor automatisch fokussiert
- Timer läuft (z.B. 8 Sekunden pro Wort)
- Bei korrekter Eingabe → nächstes Wort, Streak-Counter
- Streak-Anzeige mit Flammen-Emoji: 🔥x5
- Highscore basiert auf Geschwindigkeit + Korrektheit

Config-Format:
```json
{
    "type": "speed-round",
    "words": [
        {"prompt": "house", "correct": ["Haus"]},
        {"prompt": "school", "correct": ["Schule"]}
    ],
    "settings": {
        "timePerWord": 8,
        "streakBonus": true,
        "pointsPerCorrect": 10
    }
}
```

### 2.10 Hub.html anpassen

- Spieltyp-Icons aktualisieren:
  - `vocab-quiz` → 📝
  - `sentence-builder` → 🔀
  - `fill-blank` → ✏️
  - `mark-word` → 🎯
  - `complete-story` → 📖
  - `memory-match` → 🃏
  - `category-sort` → 📂
  - `speed-round` → ⚡
- Routing: `type` → richtige HTML-Seite verlinken
- Spiel-Karten zeigen Spieltyp-Label an

### 2.11 Backend: GameConfig erweitern (optional)

Das bestehende `GameConfig` struct hat `questions: [QuizQuestion]?`. Für die neuen Spieltypen brauchen wir flexiblere Config. Zwei Optionen:

**Option A (einfach):** Config bleibt als untypisiertes JSON. Frontend parst es selbst.
- Vorteil: Keine Backend-Änderung nötig
- Nachteil: Keine serverseitige Validierung

**Option B (typsicher):** Config als Enum mit Associated Values.
- Aufwändiger, aber sicherer

**Empfehlung: Option A für jetzt.** Das `config` Feld ist bereits JSON — das Frontend entscheidet anhand von `type`, wie es das JSON interpretiert. Keine Backend-Änderung nötig.

### 2.12 Testen

Für jeden neuen Spieltyp:
1. Testdaten via curl erstellen:
```bash
curl -X POST http://localhost:8080/api/games \
  -H "Content-Type: application/json" \
  -d '{
    "type": "memory-match",
    "title": "Vokabeln Unit 3 — Memory",
    "kompetenz": "Wortschatz",
    "config": {
        "pairs": [
            {"front": "sustainable", "back": "nachhaltig"},
            {"front": "environment", "back": "Umwelt"},
            {"front": "renewable", "back": "erneuerbar"},
            {"front": "pollution", "back": "Verschmutzung"},
            {"front": "resource", "back": "Ressource"},
            {"front": "climate", "back": "Klima"}
        ],
        "settings": {"gridCols": 4, "pointsPerPair": 20, "bonusForSpeed": true, "timeLimit": 120}
    }
  }'
```
2. Browser: Hub öffnen → Spiel erscheint → durchspielen
3. Ergebnis + Leaderboard prüfen

---

## PHASE 3: Vokabelmodus mit Spaced Repetition

### 3.1 Neues Model: VocabItem

**Datei erstellen:** `Sources/App/Models/VocabItem.swift`

```swift
final class VocabItem: Model, Content, @unchecked Sendable {
    static let schema = "vocab_items"

    @ID(key: .id) var id: UUID?
    @Field(key: "english") var english: String
    @Field(key: "german") var german: String
    @OptionalField(key: "example_sentence") var exampleSentence: String?
    @OptionalField(key: "topic") var topic: String?
    @Field(key: "difficulty") var difficulty: Int  // 1-5
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}
    init(english: String, german: String, example: String? = nil, topic: String? = nil, difficulty: Int = 1) {
        self.english = english
        self.german = german
        self.exampleSentence = example
        self.topic = topic
        self.difficulty = difficulty
    }
}
```

### 3.2 Neues Model: VocabProgress

**Datei erstellen:** `Sources/App/Models/VocabProgress.swift`

```swift
final class VocabProgress: Model, Content, @unchecked Sendable {
    static let schema = "vocab_progress"

    @ID(key: .id) var id: UUID?
    @Parent(key: "player_id") var player: Player
    @Parent(key: "vocab_id") var vocab: VocabItem
    @Field(key: "box") var box: Int                    // Leitner-Box 1-5
    @Field(key: "ease_factor") var easeFactor: Double   // SM-2, startet bei 2.5
    @Field(key: "interval_days") var intervalDays: Int  // Tage bis nächste Wiederholung
    @Field(key: "next_review") var nextReview: Date     // Nächster Fälligkeitstermin
    @Field(key: "repetitions") var repetitions: Int     // Anzahl erfolgreicher Wiederholungen
    @Field(key: "correct_streak") var correctStreak: Int

    init() {}
    init(playerID: UUID, vocabID: UUID) {
        self.$player.id = playerID
        self.$vocab.id = vocabID
        self.box = 1
        self.easeFactor = 2.5
        self.intervalDays = 0
        self.nextReview = Date()  // sofort fällig
        self.repetitions = 0
        self.correctStreak = 0
    }
}
```

### 3.3 Neue Migration

**Datei erstellen:** `Sources/App/Migrations/CreateVocabTables.swift`

Zwei Tabellen: `vocab_items` und `vocab_progress`.
- `vocab_progress` hat UNIQUE Constraint auf `(player_id, vocab_id)`
- Beide mit Foreign Keys

### 3.4 Neuer Controller: VocabController

**Datei erstellen:** `Sources/App/Controllers/VocabController.swift`

Endpoints:

**`POST /api/vocab/import`** — Batch-Import von Vokabeln
- Body: `{topic: "Unit 3", items: [{english: "...", german: "...", example: "..."}]}`
- Erstellt VocabItems in der DB
- Ignoriert Duplikate (english + german unique)

**`GET /api/vocab/due/:playerID`** — Fällige Karten
- Findet alle VocabItems, für die KEIN VocabProgress existiert ODER next_review <= heute
- Limit 20 Karten pro Session
- Erstellt VocabProgress-Einträge für neue Karten (box=1, sofort fällig)
- Gibt Karten zurück mit ihrem aktuellen Box-Level

**`POST /api/vocab/review`** — Antwort bewerten
- Body: `{playerID: UUID, vocabID: UUID, quality: Int}` (quality: 0-3)
- SM-2 Algorithmus anwenden:
  ```
  quality 0 (Nochmal): repetitions=0, interval=0, box=max(1, box-1)
  quality 1 (Schwer):  repetitions+=1, interval=1, box bleibt
  quality 2 (Gut):     repetitions+=1, interval=[1,3,7,14,30][min(rep-1,4)], box=min(5,box+1)
  quality 3 (Leicht):  repetitions+=1, interval=interval*easeFactor, box=min(5,box+1)
  easeFactor = max(1.3, easeFactor + (0.1 - (3-quality) * 0.08))
  nextReview = Date() + interval Tage
  ```
- Gibt aktualisierten VocabProgress zurück

**`GET /api/vocab/stats/:playerID`** — Lernfortschritt
- Zählt Karten pro Box (1-5)
- Gibt zurück: `{box1: 12, box2: 8, box3: 5, box4: 3, box5: 2, total: 30, dueToday: 7}`

**`GET /api/vocab/topics`** — Alle Themen
- Distinct topics aus vocab_items

### 3.5 DTOs für Vocab (in GameDTOs.swift)

```swift
struct VocabImportRequest: Content {
    var topic: String?
    var items: [VocabImportItem]
}

struct VocabImportItem: Content {
    var english: String
    var german: String
    var example: String?
}

struct VocabReviewRequest: Content {
    var playerID: UUID
    var vocabID: UUID
    var quality: Int  // 0-3
}

struct VocabDueCard: Content {
    var vocabID: UUID
    var english: String
    var german: String
    var exampleSentence: String?
    var box: Int
    var topic: String?
}

struct VocabStats: Content {
    var box1: Int
    var box2: Int
    var box3: Int
    var box4: Int
    var box5: Int
    var total: Int
    var dueToday: Int
}
```

### 3.6 configure.swift + routes.swift anpassen

```swift
// configure.swift
app.migrations.add(CreateVocabTables())

// routes.swift
try app.register(collection: VocabController())
```

### 3.7 Frontend: Karteikarten-UI

**Datei erstellen:** `Public/games/vocab-srs.html`

- Karte zeigt englisches Wort (groß, zentriert)
- "Aufdecken"-Button → deutsche Übersetzung erscheint (+ Beispielsatz)
- 4 Bewertungs-Buttons: "Nochmal" (rot), "Schwer" (orange), "Gut" (grün), "Leicht" (blau)
- Fortschritt oben: "Karte 3 / 15"
- Box-Verteilung als kleine Balken (Box 1-5)
- Am Ende: Zusammenfassung "12 von 15 richtig, 3 zum Wiederholen"

CSS: Karte mit 3D-Flip-Animation beim Aufdecken.

### 3.8 Frontend: Vocab-Upload-Seite

**Datei erstellen:** `Public/teacher/vocab-upload.html`

- Einfache Seite (gleicher Dark-Theme-Stil)
- Textfeld: "Vokabeln einfügen (eine pro Zeile, Format: english | german | example)"
- Input: Topic/Thema
- Button: "Importieren"
- Parser: Zeilen splitten bei `|`, trimmen, an API senden
- Erfolgsmeldung: "15 Vokabeln importiert!"

### 3.9 api.js erweitern

```javascript
async importVocab(topic, items) { ... }
async getDueVocab(playerID) { ... }
async reviewVocab(playerID, vocabID, quality) { ... }
async getVocabStats(playerID) { ... }
async getVocabTopics() { ... }
```

### 3.10 hub.html anpassen

- Neue Karte im Hub: "📚 Vokabeltrainer" → Link zu vocab-srs.html
- Zeigt an: "7 Karten fällig heute"
- Separate Sektion (über den Spielen): "Dein Vokabeltraining"

### 3.11 Testen

```bash
# Vokabeln importieren
curl -X POST http://localhost:8080/api/vocab/import \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "Unit 3 - Environment",
    "items": [
        {"english": "sustainable", "german": "nachhaltig", "example": "We need sustainable energy sources."},
        {"english": "environment", "german": "Umwelt", "example": "We must protect our environment."},
        {"english": "renewable", "german": "erneuerbar", "example": "Solar power is a renewable energy source."},
        {"english": "pollution", "german": "Verschmutzung", "example": "Air pollution is a serious problem."},
        {"english": "climate change", "german": "Klimawandel", "example": "Climate change affects everyone."}
    ]
  }'

# Fällige Karten abrufen
curl http://localhost:8080/api/vocab/due/PLAYER_UUID_HERE

# Karte bewerten
curl -X POST http://localhost:8080/api/vocab/review \
  -H "Content-Type: application/json" \
  -d '{"playerID": "...", "vocabID": "...", "quality": 2}'
```

---

## PHASE 4: Personalisierte Aufgaben

### 4.1 Neues Model: PersonalTask

**Datei erstellen:** `Sources/App/Models/PersonalTask.swift`

```swift
final class PersonalTask: Model, Content, @unchecked Sendable {
    static let schema = "personal_tasks"

    @ID(key: .id) var id: UUID?
    @Parent(key: "player_id") var player: Player
    @Field(key: "title") var title: String
    @Field(key: "type") var type: String              // Spieltyp (vocab-quiz, fill-blank, etc.)
    @Field(key: "config") var config: GameConfig       // Gleiche Config wie GameModule
    @Timestamp(key: "assigned_at", on: .create) var assignedAt: Date?
    @Field(key: "completed") var completed: Bool
    @OptionalField(key: "completed_at") var completedAt: Date?
    @OptionalField(key: "due_date") var dueDate: Date?
    @OptionalField(key: "note") var note: String?      // Hinweis der Lehrkraft

    init() {}
}
```

### 4.2 Migration + Controller + DTOs

Analog zu den bisherigen Patterns. Endpoints:
- `POST /api/personal/assign` — Aufgabe zuweisen (Body: playerID, title, type, config, note?, dueDate?)
- `GET /api/personal/:playerID` — Offene Aufgaben (completed == false)
- `POST /api/personal/:taskID/complete` — Als erledigt markieren
- `GET /api/personal/:playerID/all` — Alle Aufgaben (auch erledigte)

### 4.3 hub.html: Personalisierter Bereich

- Beim Laden: `GET /api/personal/:playerID` aufrufen
- Falls Aufgaben vorhanden: Gelb hinterlegter Bereich "📋 Deine Aufgaben" anzeigen
- Jede Aufgabe als Karte mit: Titel, Typ-Icon, Fälligkeitsdatum, Lehrkraft-Notiz
- Klick → Zum entsprechenden Spieltyp mit Task-Config laden
- Nach Abschluss: `POST /api/personal/:taskID/complete` aufrufen

---

## PHASE 5: Online-Zugang (Cloudflare Tunnel)

> **Hinweis:** Ein Cloudflare-Account existiert bereits. Falls auch eine Domain bei Cloudflare verwaltet wird, kann direkt ein Named Tunnel mit Subdomain erstellt werden.

### 5.1 Cloudflared installieren

```bash
brew install cloudflared
```

### 5.2 Tunnel erstellen (mit bestehendem Account)

```bash
# Bei Cloudflare anmelden (Browser öffnet sich → bestehendes Konto wählen)
cloudflared tunnel login

# Tunnel erstellen
cloudflared tunnel create lernspiel
# → Notiere die TUNNEL_ID aus der Ausgabe

# DNS-Route setzen (Subdomain unter deiner Domain)
cloudflared tunnel route dns lernspiel lernspiel.DEINE-DOMAIN.de
```

### 5.3 Config-Datei erstellen

```bash
cat > ~/.cloudflared/config.yml << 'EOF'
tunnel: TUNNEL_ID_HIER
credentials-file: /Users/DEIN_USER/.cloudflared/TUNNEL_ID_HIER.json

ingress:
  - hostname: lernspiel.DEINE-DOMAIN.de
    service: http://localhost:8080
  - service: http_status:404
EOF
```

**Ersetze:** `TUNNEL_ID_HIER` durch die echte Tunnel-ID, `DEIN_USER` durch den macOS-Benutzernamen, `DEINE-DOMAIN.de` durch die echte Domain.

### 5.4 Tunnel testen

```bash
cloudflared tunnel run lernspiel
# → Browser: https://lernspiel.DEINE-DOMAIN.de → sollte LernSpiel-Login zeigen
```

### 5.5 Quick-Tunnel (ohne eigene Domain, zum schnellen Testen)

```bash
cloudflared tunnel --url http://localhost:8080
# → Gibt temporäre URL: https://random-name.trycloudflare.com
# → Wechselt bei jedem Neustart! Nur für Tests.
```

### 5.6 Autostart als LaunchAgent

Damit sowohl der Vapor-Server als auch der Cloudflare-Tunnel beim Mac-Mini-Boot automatisch starten:

**a) Vapor-Server LaunchAgent:**

```bash
cat > ~/Library/LaunchAgents/com.lernspiel.server.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lernspiel.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/DEIN_USER/LernSpiel/.build/release/App</string>
        <string>serve</string>
        <string>--hostname</string>
        <string>0.0.0.0</string>
        <string>--port</string>
        <string>8080</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/DEIN_USER/LernSpiel</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/DEIN_USER/LernSpiel/logs/server.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/DEIN_USER/LernSpiel/logs/server-error.log</string>
</dict>
</plist>
EOF
```

**b) Cloudflare Tunnel LaunchAgent:**

```bash
cat > ~/Library/LaunchAgents/com.lernspiel.tunnel.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lernspiel.tunnel</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/cloudflared</string>
        <string>tunnel</string>
        <string>run</string>
        <string>lernspiel</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/DEIN_USER/LernSpiel/logs/tunnel.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/DEIN_USER/LernSpiel/logs/tunnel-error.log</string>
</dict>
</plist>
EOF
```

**c) LaunchAgents aktivieren:**

```bash
# Log-Verzeichnis erstellen
mkdir -p ~/LernSpiel/logs

# Agents laden
launchctl load ~/Library/LaunchAgents/com.lernspiel.server.plist
launchctl load ~/Library/LaunchAgents/com.lernspiel.tunnel.plist

# Prüfen ob sie laufen
launchctl list | grep lernspiel
```

### 5.7 CORS einschränken

In `configure.swift` die CORS-Config anpassen (statt `.all` nur eigene Domain):
```swift
let corsConfig = CORSMiddleware.Configuration(
    allowedOrigin: .custom("https://lernspiel.DEINE-DOMAIN.de"),
    // ...
)
```

### 5.8 Schulnetzwerk-Hinweis

Cloudflare Tunnel nutzt **Standard-HTTPS (Port 443)** — funktioniert aus jedem Schulnetzwerk wie eine normale Website. Falls die Domain dennoch blockiert wird: IT-Admin bitten, die Subdomain freizuschalten.

---

## Zusammenfassung: Neue Dateien

| Phase | Neue Dateien |
|-------|-------------|
| 1 | `Models/LernraumCheckin.swift`, `Controllers/LernraumController.swift`, `Migrations/CreateLernraumCheckin.swift`, `Public/lernraum.html` |
| 2 | `Public/js/game-engine.js`, `Public/games/sentence-builder.html`, `Public/games/fill-blank.html`, `Public/games/mark-word.html`, `Public/games/complete-story.html`, `Public/games/memory-match.html`, `Public/games/category-sort.html`, `Public/games/speed-round.html` |
| 3 | `Models/VocabItem.swift`, `Models/VocabProgress.swift`, `Controllers/VocabController.swift`, `Migrations/CreateVocabTables.swift`, `Public/games/vocab-srs.html`, `Public/teacher/vocab-upload.html` |
| 4 | `Models/PersonalTask.swift`, `Controllers/PersonalTaskController.swift`, `Migrations/CreatePersonalTask.swift` |

## Zusammenfassung: Geänderte Dateien

Alle Phasen: `configure.swift`, `routes.swift`, `GameDTOs.swift`, `Public/js/api.js`, `Public/hub.html`
Phase 1 extra: `Public/js/auth.js`, `Public/index.html`
Phase 2 extra: `Public/css/style.css`, `Public/games/vocab-quiz.html` (refactoring)

---

## Wichtige Hinweise

1. **Immer `swift build` nach Backend-Änderungen** — Kompiliert den Server neu
2. **Datenbank löschen bei Schema-Problemen:** `rm lernspiel.sqlite` (Daten gehen verloren!)
3. **Touch-Support testen** — Alle Drag & Drop Spiele MÜSSEN auf iPad funktionieren
4. **Responsive testen** — Maximale Breite 480px, funktioniert auf allen Geräten
5. **Dark Theme beibehalten** — Gleiche Farben wie bestehendes CSS
6. **`@Sendable` und `@unchecked Sendable`** — Alle Controller-Funktionen und Models brauchen dies
7. **Migrations-Reihenfolge** — Neue Migrations NACH den bestehenden 3 hinzufügen
