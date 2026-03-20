# Plattform-SRL — Restore Guide

Anleitung zur vollständigen Wiederherstellung auf einem neuen macOS-Account oder Mac.

## Voraussetzungen

- macOS mit Apple Silicon (arm64)
- Xcode installiert (inkl. Command Line Tools)
- Das `age`-Passwort für `secrets.age`

## 1. Homebrew installieren

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
```

## 2. Abhängigkeiten installieren

```bash
brew install cloudflared age
```

## 3. Repository klonen

```bash
cd ~
git clone https://github.com/TomNeren/Lernraum-Check.git Plattform-SRL
cd Plattform-SRL
```

## 4. Secrets entschlüsseln und einspielen

```bash
# Entschlüsseln (fragt nach dem Passwort)
age -d -o /tmp/srl-secrets.tar secrets.age

# .env ins Projekt kopieren
tar xf /tmp/srl-secrets.tar -C . .env

# Cloudflare-Credentials nach ~/.cloudflared/ kopieren
mkdir -p ~/.cloudflared
tar xf /tmp/srl-secrets.tar -C ~ .cloudflared/

# Aufräumen
rm /tmp/srl-secrets.tar
```

## 5. Projekt bauen und starten

```bash
cd ~/Plattform-SRL
swift build
swift run App
```

Die App läuft auf `http://localhost:8090`.

## 6. Cloudflare Tunnel als Service einrichten

LaunchAgent erstellen:

```bash
cat > ~/Library/LaunchAgents/com.cloudflare.tunnel.srl.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cloudflare.tunnel.srl</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/cloudflared</string>
        <string>tunnel</string>
        <string>run</string>
        <string>SRL</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/cloudflared-srl.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/cloudflared-srl-error.log</string>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.cloudflare.tunnel.srl.plist
```

Die Plattform ist dann erreichbar unter: **https://SRL.infotore.cc**

## 7. App als Service einrichten (optional)

Damit die App automatisch beim Login startet:

```bash
cat > ~/Library/LaunchAgents/com.srl.plattform.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.srl.plattform</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/USER/Plattform-SRL/.build/debug/App</string>
        <string>serve</string>
        <string>--hostname</string>
        <string>0.0.0.0</string>
        <string>--port</string>
        <string>8090</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/USER/Plattform-SRL</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/srl-plattform.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/srl-plattform-error.log</string>
</dict>
</plist>
EOF
```

**Wichtig:** Ersetze `USER` durch deinen macOS-Benutzernamen, dann:

```bash
launchctl load ~/Library/LaunchAgents/com.srl.plattform.plist
```

## Technische Details

- **Framework:** Vapor 4.89+ (Swift)
- **Datenbank:** SQLite (wird automatisch erstellt)
- **Swift Version:** 5.9+
- **Port:** 8090
- **Domain:** SRL.infotore.cc (via Cloudflare Tunnel)
