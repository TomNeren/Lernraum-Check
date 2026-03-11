# LernSpiel — Next Steps

## Priority 1: Configuration (before next school session)

### Create `.env` file
Copy from `.env.example` and fill in real values:
```bash
cp .env.example .env
```
Required settings:
| Variable | Status | Notes |
|----------|--------|-------|
| `ADMIN_PASSWORD` | Set a strong password | Used for admin dashboard login |
| `CLAUDE_API_KEY` | `sk-ant-...` | Needed for AI feedback feature |
| `CLAUDE_MODEL` | `claude-haiku-4-5-20251001` | Default is fine, cheapest option |
| `GOOGLE_API_KEY` | `AIza...` | Gemini API key for additional AI services |
| `PORT` | `8090` | Already configured |
| `MAX_UPLOAD_MB` | `50` | For PDF uploads |

### Test API connections
Once `.env` is set:
```
POST https://srl.infotore.cc/api/ai/config
```
This verifies the Claude API key works. Gemini endpoint testing TBD.

---

## Priority 2: Security hardening

### Restrict CORS
In `Sources/App/configure.swift`, change CORS from `.all` to:
```swift
.custom("https://srl.infotore.cc")
```
Prevents other websites from calling the API.

### Add API authentication for teacher endpoints
Currently anyone can create/delete games and manage students. Add an API-key header check for sensitive POST/DELETE routes (game creation, student management, PDF upload).

---

## Priority 3: Data safety

### Set up automatic database backups
Add a cron job to back up the SQLite database daily:
```bash
crontab -e
# Add this line:
0 2 * * * cp /Users/thomasrenne/Plattform-SRL/lernspiel.sqlite /Users/thomasrenne/backups/lernspiel_$(date +\%Y\%m\%d).sqlite
```
Create the backups directory first: `mkdir -p ~/backups`

---

## Priority 4: Testing & polish

### Test new features end-to-end
- [ ] Student chat: send message from hub, verify it appears in admin Chat tab
- [ ] PDF upload: upload a PDF from admin, download it, verify metadata filters work
- [ ] AI feedback: play a game, trigger feedback, check response quality
- [ ] Glassmorphism UI: test on iPad/mobile browsers (Safari, Chrome)
- [ ] All 8 game types still load and play correctly

### Test with real student load
- [ ] Create 5-10 test students across 2 classes
- [ ] Run multiple games simultaneously
- [ ] Check admin stats update correctly

---

## Priority 5: Multi-model AI strategy

### Current: Claude API (server-side)
- Used for: general AI feedback, PDF analysis
- Runs on server, costs per API call
- Best for complex reasoning and longer responses

### Add: Gemini API (server-side)
- `GOOGLE_API_KEY` already in `.env.example`
- Use for: alternative/fallback AI provider, cost balancing
- Implement model router in AIFeedbackController to choose provider based on task type or load

### Add: Apple Foundation Models (on-device, zero cost)
- Use for: **vocab feedback** and **game feedback** — high-frequency, short responses
- Runs locally on Apple Silicon (Mac Mini M-series) via Foundation Models framework
- Zero API cost, low latency, works offline
- Ideal for quick student-facing responses like:
  - "Great job! You got 8/10 — review 'der Tisch' and 'die Lampe'"
  - "Try breaking the sentence into subject-verb-object"
  - Vocab hints and mnemonics
  - Game score commentary
- Requires: macOS 26+ with Apple Intelligence, Swift integration via `FoundationModels` framework
- Implementation: Add `AppleLMProvider` alongside existing Claude provider, route vocab/game feedback through it

### Model routing strategy
| Feedback type | Primary model | Fallback |
|---------------|--------------|----------|
| Vocab tips & hints | Apple Foundation Models (free, fast) | Claude Haiku |
| Game score feedback | Apple Foundation Models (free, fast) | Claude Haiku |
| General Q&A | Claude Haiku | Gemini |
| PDF analysis | Claude Sonnet | Gemini |
| Complex learning plans | Claude Sonnet | Gemini |

---

## Priority 6: Future features (nice to have)

### Rate limiting
Add IP-based rate limiting to prevent spam, especially on:
- Chat messages
- AI feedback requests (costs money per API call — less critical if using Apple FM)

### Student progress dashboard
A student-facing view showing their:
- Game scores over time
- Vocab SRS box distribution
- Completed personal tasks

### PDF integration with AI
Let Claude/Gemini read uploaded PDFs and generate quiz questions automatically.

### Push notifications for teachers
Alert when a student sends a chat message (browser notifications or email).

---

## Quick reference: How to update & deploy

```bash
# 1. Pull latest from GitHub
cd /Users/thomasrenne/Plattform-SRL
git fetch origin main
git checkout origin/main -- .

# 2. Rebuild
swift build

# 3. Stop old server
lsof -i :8090 | awk 'NR>1 {print $2}' | xargs kill

# 4. Start new server
swift run App serve --hostname 0.0.0.0 --port 8090 &

# Cloudflare tunnel runs automatically via LaunchAgent
```

---

## Project status summary

| Feature | Status |
|---------|--------|
| Player login & classes | Done |
| 8 game types | Done |
| Lernraum check-in/out | Done |
| Vocab SRS (Leitner + SM-2) | Done |
| Personal tasks | Done |
| Admin dashboard | Done |
| QR lesson codes | Done |
| Content assignments | Done |
| Student chat | Done (new) |
| PDF database | Done (new) |
| AI feedback (Claude) | Done (needs API key) |
| Glassmorphism UI | Done (new) |
| CORS restriction | TODO |
| Database backups | TODO |
| Rate limiting | TODO |
