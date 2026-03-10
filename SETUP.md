# LernSpiel — Setup-Anleitung für Mac Mini

## Voraussetzungen

- macOS 13 (Ventura) oder neuer
- Xcode 15+ (aus dem App Store) — wird für die Swift-Toolchain benötigt
- Mac Mini per LAN-Kabel am Router

## 1. Projekt auf den Mac Mini kopieren

Den gesamten `LernSpiel/`-Ordner auf den Mac Mini kopieren (AirDrop, USB, Git...).

```bash
# z.B. ins Home-Verzeichnis
cd ~
# LernSpiel-Ordner hierhin kopieren
ls ~/LernSpiel/Package.swift  # Prüfen, ob vorhanden
```

## 2. Projekt bauen

```bash
cd ~/LernSpiel
swift build
```

Beim ersten Mal lädt Swift alle Dependencies (Vapor, Fluent, SQLite). Das dauert 2-5 Minuten.

Falls `swift` nicht gefunden wird:
```bash
# Xcode Command Line Tools installieren
xcode-select --install
```

## 3. Server starten

```bash
cd ~/LernSpiel
swift run App serve --hostname 0.0.0.0 --port 8090
```

- `0.0.0.0` = erreichbar für alle Geräte im Netzwerk
- Port `8090` = Standard (änderbar)

Der Server zeigt: `Server starting on http://0.0.0.0:8090`

## 4. Im Browser öffnen

### Mac Mini IP herausfinden:
```bash
# In einem neuen Terminal:
ipconfig getifaddr en0    # LAN
# oder
ipconfig getifaddr en1    # WLAN
```

Beispiel: `192.168.1.42`

### Auf SuS-Geräten öffnen:
```
http://192.168.1.42:8080
```

Tipp: QR-Code generieren (z.B. über Lernraum-Check oder qr-code-generator.com) und im Klassenzimmer zeigen.

## 5. Erstes Spiel anlegen (Test)

Mit curl vom Mac Mini:

```bash
curl -X POST http://localhost:8090/api/games \
  -H "Content-Type: application/json" \
  -d '{
    "type": "vocab-quiz",
    "title": "Vokabeltest LS 1 — American Dream",
    "kompetenz": "Leseverstehen",
    "lsNumber": 1,
    "soloLevel": "uni",
    "config": {
      "questions": [
        {
          "id": "'$(uuidgen)'",
          "prompt": "sustainable",
          "correct": "nachhaltig",
          "distractors": ["erreichbar", "haltbar", "verträglich"],
          "example": "We need sustainable energy sources.",
          "timeLimit": 15
        },
        {
          "id": "'$(uuidgen)'",
          "prompt": "opportunity",
          "correct": "Gelegenheit",
          "distractors": ["Gegenteil", "Möglichkeit", "Hindernis"],
          "example": "Everyone deserves equal opportunities.",
          "timeLimit": 15
        },
        {
          "id": "'$(uuidgen)'",
          "prompt": "achieve",
          "correct": "erreichen",
          "distractors": ["vermeiden", "empfangen", "verlieren"],
          "example": "She worked hard to achieve her goals.",
          "timeLimit": 15
        },
        {
          "id": "'$(uuidgen)'",
          "prompt": "immigrant",
          "correct": "Einwanderer",
          "distractors": ["Auswanderer", "Tourist", "Bewohner"],
          "example": "Millions of immigrants came to America.",
          "timeLimit": 15
        },
        {
          "id": "'$(uuidgen)'",
          "prompt": "diversity",
          "correct": "Vielfalt",
          "distractors": ["Einheit", "Mehrheit", "Unterschied"],
          "example": "Cultural diversity enriches our society.",
          "timeLimit": 15
        }
      ],
      "settings": {
        "shuffleQuestions": true,
        "showExamples": true,
        "pointsPerCorrect": 10,
        "bonusForSpeed": true,
        "timeLimit": 15
      }
    }
  }'
```

## 6. Autostart einrichten (optional)

Damit der Server beim Hochfahren des Mac Mini automatisch startet:

```bash
# Release-Build erstellen (schnellerer Start)
cd ~/LernSpiel
swift build -c release

# LaunchAgent erstellen
mkdir -p ~/Library/LaunchAgents

cat > ~/Library/LaunchAgents/com.lernspiel.server.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lernspiel.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/DEIN_USERNAME/LernSpiel/.build/release/App</string>
        <string>serve</string>
        <string>--hostname</string>
        <string>0.0.0.0</string>
        <string>--port</string>
        <string>8080</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/DEIN_USERNAME/LernSpiel</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/lernspiel.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/lernspiel-error.log</string>
</dict>
</plist>
EOF

# DEIN_USERNAME ersetzen!
# Dann aktivieren:
launchctl load ~/Library/LaunchAgents/com.lernspiel.server.plist
```

## 7. Backup

Die gesamte Datenbank ist eine einzige Datei:
```bash
# Backup erstellen
cp ~/LernSpiel/lernspiel.sqlite ~/LernSpiel/backups/lernspiel_$(date +%Y%m%d).sqlite
```

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| `swift: command not found` | `xcode-select --install` |
| Port 8090 belegt | Anderen Port nutzen: `--port 8091` |
| SuS können nicht verbinden | Firewall: Systemeinstellungen → Netzwerk → Firewall → App erlauben |
| Langsam beim ersten Build | Normal — Dependencies werden kompiliert. Danach schnell. |
| `address already in use` | Alter Prozess läuft noch: `lsof -i :8090` dann `kill [PID]` |
