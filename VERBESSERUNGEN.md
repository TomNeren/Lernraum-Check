# LernSpiel — Analyse & Verbesserungsvorschläge

> Analyse des Planungsprozesses und Empfehlungen für die Weiterentwicklung.
> Stand: 08.03.2026

---

## 1. Analyse des Planungsprozesses

### Was gut lief

**Klare Vision vom Anfang an:**
Die Kernfunktionen waren von Beginn an definiert — Lernraum-Erfassung als Pflicht, Gamification und Personalisierung als Erweiterung. Diese Priorisierung ermöglicht einen schrittweisen Rollout.

**Aufbauen auf bestehendem MVP:**
Statt bei Null anzufangen, wird auf einer funktionierenden Codebasis aufgebaut. Das Vocab-Quiz beweist, dass die Architektur funktioniert.

**Pragmatische Technologie-Entscheidungen:**
- Cloudflare Tunnel statt kompliziertem Hosting
- SQLite statt PostgreSQL (für den Piloten ausreichend)
- Manuelle Claude-Integration statt Over-Engineering

### Was verbessert werden könnte

**Tech-Stack-Überlegung kam spät:**
Die Frage "Warum Swift/Vapor?" hätte idealerweise vor dem Programmieren geklärt werden sollen. Swift/Vapor ist funktional, aber für diesen Use Case (Schul-App, Claude-Integration, Rapid Prototyping) wäre Node.js oder Python pragmatischer gewesen. **Empfehlung für die Zukunft:** Bei neuen Projekten zuerst den Stack anhand der Anforderungen wählen, nicht anhand der Plattform.

**Frontend-Architektur skaliert begrenzt:**
10+ separate HTML-Dateien für Spiele werden schwer wartbar. Die geplante Game Engine hilft, aber langfristig könnte ein leichtgewichtiges Framework (z.B. Alpine.js oder Petite-Vue) die Wartbarkeit verbessern — ohne den Einfachheits-Vorteil von Vanilla JS aufzugeben.

---

## 2. Technische Verbesserungsvorschläge

### Kurzfristig (vor dem Pilot)

**a) Fehlerbehandlung verbessern**
- Backend: Einheitliche Error-Response-Struktur (`{error: String, code: Int}`)
- Frontend: Globaler Error-Handler statt try-catch in jeder Funktion
- Offline-Erkennung: Nachricht wenn Server nicht erreichbar

**b) Input-Validierung**
- Backend: Alle Eingaben validieren (Länge, Zeichen, SQL-Injection-Schutz)
- Frontend: Doppelklick-Schutz auf Submit-Buttons
- Rate Limiting: Einfacher Counter pro IP (gegen Spam)

**c) Automatische Tests**
- curl-basierte Integrationstests als Shell-Skript
- Sicherstellt, dass nach jeder Änderung alle Endpoints funktionieren
- Beispiel: `test.sh` das Login → Checkin → Spiel → Score durchläuft

**d) Datenbank-Backup automatisieren**
```bash
# Cron-Job: Tägliches Backup um 2:00 Uhr
0 2 * * * cp ~/LernSpiel/lernspiel.sqlite ~/LernSpiel/backups/lernspiel_$(date +\%Y\%m\%d).sqlite
# Backups älter als 30 Tage löschen
0 3 * * * find ~/LernSpiel/backups -name "*.sqlite" -mtime +30 -delete
```

### Mittelfristig (nach dem Pilot)

**e) Lehrkraft-Authentifizierung**
- Aktuell kann jeder Spiele erstellen und Aufgaben zuweisen (kein Auth auf `/api/games` POST)
- Einfachste Lösung: API-Key im Header für Lehrkraft-Endpoints
- Besser: Separates Login mit Rolle "teacher" im Player-Model

**f) Datenexport für Forschung**
- CSV-Export aller Lernraum-Check-ins (wer, wo, wann, wie lange)
- CSV-Export aller Spiel-Sessions (wer, was, Score, Zeit, Details)
- Wichtig für die SRL-Pilotauswertung

**g) Progressive Web App (PWA)**
- `manifest.json` + Service Worker hinzufügen
- SuS können die App zum Homescreen hinzufügen
- Offline-Cache für statische Dateien
- Push-Notifications ("Du hast 12 fällige Vokabelkarten")

**h) Analytics-Dashboard**
- Welche Spiele werden am meisten gespielt?
- Zu welchen Zeiten sind SuS aktiv?
- Welche Vokabeln/Fragen haben die niedrigste Erfolgsquote?
- Durchschnittliche Lernzeit pro Session

### Langfristig

**i) Adaptive Schwierigkeit**
- Wenn ein/e Lernende/r regelmäßig >90% erreicht: Schwierigere Fragen
- Wenn <50%: Einfachere Fragen oder Hinweise anzeigen
- Item-Response-Theorie (IRT) für Fragen-Kalibrierung

**j) Peer-Learning**
- SuS können eigene Quiz erstellen (moderiert durch Lehrkraft)
- "Challenge a Friend" — Direktes Duell im gleichen Quiz
- Klassen-Rankings und Team-Wettbewerbe

**k) Multi-Fach-Support**
- Aktuell: Nur Englisch
- Erweiterung: Deutsch, Mathe, andere Fächer
- Fach-Feld im GameModule-Model hinzufügen

---

## 3. UX/Design-Verbesserungen

**a) Onboarding für neue SuS**
- Erste Anmeldung: Kurze Tour ("So funktioniert LernSpiel")
- Erklärung des SRS-Systems ("Warum kommen manche Karten öfter?")

**b) Motivations-Elemente erweitern**
- Tagesstreak-Counter ("5 Tage in Folge gelernt! 🔥")
- Achievements/Badges ("100 Vokabeln gelernt", "Erstes Perfect Game")
- Wöchentliche Zusammenfassung ("Diese Woche: 3 Spiele, 150 Punkte")

**c) Barrierefreiheit**
- Schriftgrößen-Anpassung
- High-Contrast-Modus (alternativ zum Dark Theme)
- Screenreader-kompatible Labels
- Keyboard-Navigation für alle Spiele

**d) Ladezeiten optimieren**
- CSS/JS minifizieren (oder als Build-Step)
- Bilder komprimieren (falls welche verwendet werden)
- Lazy Loading für Leaderboard und Statistiken

---

## 4. Prozess-Verbesserungen

**a) Versionierung einführen**
- Git-Repository initialisieren
- Branching: `main` (stabil) + `dev` (Entwicklung)
- Semantic Versioning: v0.1.0 → v0.2.0 (Lernraum) → v0.3.0 (Spiele) etc.
- CHANGELOG.md pflegen

**b) Deployment-Pipeline**
- `make deploy` oder Shell-Skript das:
  1. Tests ausführt
  2. Release-Build erstellt
  3. Server neu startet
  4. Backup erstellt

**c) Monitoring**
- Health-Check-Endpoint regelmäßig pingen (z.B. UptimeRobot, kostenlos)
- Log-Rotation für Server-Logs
- Disk-Space-Warnung wenn SQLite > 1GB

**d) Dokumentation aktuell halten**
- API-Docs automatisch generieren (Swagger/OpenAPI)
- Jede neue Phase: CHANGELOG und DOKUMENTATION.md aktualisieren

---

## 5. Sicherheits-Empfehlungen

| Bereich | Aktuell | Empfohlen |
|---------|---------|-----------|
| HTTPS | Nur via Cloudflare | Cloudflare Tunnel reicht |
| Auth | Name+Klasse, kein Passwort | OK für Pilot, API-Key für Lehrkraft-Endpoints |
| CORS | `allowedOrigin: .all` | Auf eigene Domain einschränken |
| Rate Limiting | Keins | Einfacher IP-basierter Counter |
| Input Validation | Minimal (Trim + Empty-Check) | Länge, Zeichen, Typ-Prüfung |
| SQL Injection | Fluent ORM schützt | OK, keine Raw-Queries |
| XSS | Kein Escaping im Frontend | `textContent` statt `innerHTML` wo möglich |
| Backup | Manuell | Automatisierter Cron-Job |

---

## 6. Metriken für den SRL-Pilot

Folgende Daten sollten für die Pilotauswertung erfasst werden (die meisten sind bereits durch das Session-Tracking abgedeckt):

- **Lernraum-Nutzung:** Welche Räume werden wie oft gewählt? Wie lange bleiben SuS?
- **Spielaktivität:** Welche Spiele werden gespielt? Wie oft? Zu welchen Zeiten?
- **Lernfortschritt:** Verbesserung der Scores über Zeit? SRS-Box-Verteilung?
- **Selbstregulation:** Wechseln SuS den Raum? Spielen sie freiwillig? Nutzen sie den SRS-Trainer?
- **Personalisierung:** Werden zugewiesene Aufgaben erledigt? In welcher Zeit?

**Export-Endpoint bauen:** `GET /api/export/sessions?from=2026-03-01&to=2026-07-01` → CSV

---

## 7. Zusammenfassung: Top-5 nächste Schritte

1. **Git initialisieren** — Versionskontrolle bevor weitere Änderungen gemacht werden
2. **Phase 1 implementieren** — Lernraum-Erfassung (Kernfunktion für Pilot)
3. **Cloudflare Tunnel einrichten** — Online-Zugang sofort verfügbar machen
4. **Automatisches Backup** — Cron-Job für tägliche DB-Sicherung
5. **Lehrkraft-API-Key** — Einfacher Schutz für Spiel-Erstellung und Aufgaben-Zuweisung
