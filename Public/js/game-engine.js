/**
 * LernSpiel Game Engine
 * Gemeinsame Basis für alle Spieltypen: Timer, Scoring, Progress, Views, Results
 */

class GameEngine {
    constructor(options = {}) {
        this.gameModule = null;
        this.score = 0;
        this.maxScore = 0;
        this.totalItems = 0;
        this.correctCount = 0;
        this.wrongCount = 0;
        this.answers = [];
        this.timerInterval = null;
        this.timeLeft = 0;
        this.questionStartTime = 0;
        this.answered = false;
        this.gameStartTime = 0;
        this._timerEl = null;

        // Callbacks
        this.onGameLoaded = options.onGameLoaded || null;
        this.onBuildReview = options.onBuildReview || null;

        // Cleanup on page unload
        window.addEventListener('beforeunload', () => this.stopTimer());
    }

    get settings() {
        return this.gameModule?.config?.settings || {};
    }

    // --- Init ---
    async init() {
        const params = new URLSearchParams(window.location.search);
        const gameID = params.get('game');

        if (!gameID) {
            this.showError('Kein Spiel ausgewählt.');
            return null;
        }

        try {
            this.gameModule = await API.getGame(gameID);
            this.gameStartTime = Date.now();

            if (this.onGameLoaded) {
                this.onGameLoaded(this.gameModule);
            }

            return this.gameModule;
        } catch (e) {
            this.showError(`Spiel konnte nicht geladen werden: ${e.message}`);
            return null;
        }
    }

    // --- Timer ---
    startTimer(seconds, onTimeUp) {
        this.timeLeft = seconds;
        this.questionStartTime = Date.now();
        this.updateTimerDisplay();
        clearInterval(this.timerInterval);
        this.timerInterval = setInterval(() => {
            this.timeLeft--;
            this.updateTimerDisplay();
            if (this.timeLeft <= 0) {
                clearInterval(this.timerInterval);
                if (onTimeUp) onTimeUp();
            }
        }, 1000);
    }

    stopTimer() {
        clearInterval(this.timerInterval);
    }

    updateTimerDisplay() {
        if (!this._timerEl) this._timerEl = document.getElementById('timer');
        const el = this._timerEl;
        if (!el) return;
        el.textContent = this.timeLeft;
        if (this.timeLeft <= 5) {
            el.className = 'timer danger';
        } else if (this.timeLeft <= 10) {
            el.className = 'timer warning';
        } else {
            el.className = 'timer';
        }
    }

    getElapsedSeconds() {
        return Math.round((Date.now() - this.questionStartTime) / 1000);
    }

    // --- Scoring ---
    calculatePoints(isCorrect, settings) {
        if (!isCorrect) return 0;
        let points = settings.pointsPerCorrect || 10;
        if (settings.bonusForSpeed && this.timeLeft > 0) {
            const maxTime = settings.timeLimit || 15;
            const bonus = Math.round((this.timeLeft / maxTime) * (points / 2));
            points += bonus;
        }
        return points;
    }

    addScore(points) {
        this.score += points;
        const badge = document.getElementById('score-badge');
        if (badge) badge.textContent = `${this.score} Punkte`;
    }

    // --- Progress ---
    updateProgress(current, total) {
        const fill = document.getElementById('progress-fill');
        if (fill) fill.style.width = `${(current / total) * 100}%`;
        const counter = document.getElementById('question-counter');
        if (counter) counter.textContent = `${current + 1} / ${total}`;
    }

    // --- Feedback ---
    showFeedback(isCorrect, points, correctAnswer) {
        const feedback = document.getElementById('feedback-area');
        if (!feedback) return;

        if (isCorrect) {
            feedback.innerHTML = `<span style="color: var(--success); font-weight: 600;">
                Richtig! +${points} Punkte</span>`;
        } else {
            feedback.innerHTML = `<span style="color: var(--danger);">
                Falsch — Richtig wäre: <strong>${GameEngine.escapeHTML(correctAnswer)}</strong></span>`;
        }
    }

    showTimeUpFeedback(correctAnswer) {
        const feedback = document.getElementById('feedback-area');
        if (!feedback) return;
        feedback.innerHTML = `<span style="color: var(--warning);">
            Zeit abgelaufen! Richtig: <strong>${GameEngine.escapeHTML(correctAnswer)}</strong></span>`;
    }

    clearFeedback() {
        const feedback = document.getElementById('feedback-area');
        if (feedback) feedback.innerHTML = '';
    }

    // --- Shake Animation ---
    shake(element) {
        element.classList.add('shake');
        setTimeout(() => element.classList.remove('shake'), 500);
    }

    // --- Finish Game ---
    async finishGame() {
        this.stopTimer();
        const totalTime = Math.round((Date.now() - this.gameStartTime) / 1000);
        const percent = this.totalItems > 0
            ? Math.round((this.correctCount / this.totalItems) * 100)
            : 0;

        // Progress voll
        const fill = document.getElementById('progress-fill');
        if (fill) fill.style.width = '100%';

        // Score senden
        try {
            await API.submitScore({
                playerID: Auth.getPlayerID(),
                moduleID: this.gameModule.id,
                score: this.score,
                maxScore: this.maxScore,
                timeSpent: totalTime,
                details: { answers: this.answers }
            });
        } catch (e) {
            console.error('Score senden fehlgeschlagen:', e);
        }

        // Results View
        this.showView('view-results');

        // Konfetti bei >= 70%
        if (percent >= 70) this.showConfetti();

        // Emoji
        const emoji = percent >= 90 ? '🏆' : percent >= 70 ? '🎉' : percent >= 50 ? '👍' : '💪';
        const emojiEl = document.getElementById('results-emoji');
        if (emojiEl) emojiEl.textContent = emoji;

        const scoreEl = document.getElementById('final-score');
        if (scoreEl) scoreEl.textContent = this.score;
        const percentEl = document.getElementById('final-percent');
        if (percentEl) percentEl.textContent = `${percent}% richtig`;
        const correctEl = document.getElementById('result-correct');
        if (correctEl) correctEl.textContent = this.correctCount;
        const wrongEl = document.getElementById('result-wrong');
        if (wrongEl) wrongEl.textContent = this.wrongCount;
        const timeEl = document.getElementById('result-time');
        if (timeEl) timeEl.textContent = `${totalTime}s`;

        // Answer Review (custom or default)
        if (this.onBuildReview) {
            this.onBuildReview(this.answers);
        }

        // KI-Feedback anfordern (async, non-blocking)
        this.requestAIFeedback();

        // Leaderboard
        this.loadLeaderboard();
    }

    async loadLeaderboard() {
        try {
            const entries = await API.getLeaderboard(this.gameModule.id);
            const container = document.getElementById('leaderboard');
            if (!container) return;

            if (entries.length === 0) {
                container.innerHTML = '<div class="text-muted text-sm text-center">Noch keine Einträge.</div>';
                return;
            }

            container.innerHTML = entries.slice(0, 10).map(entry => {
                const rankClass = entry.rank <= 3 ? `top-${entry.rank}` : '';
                const isMe = entry.playerName === Auth.getPlayerName();
                return `
                    <div class="leaderboard-item" ${isMe ? 'style="border: 1px solid var(--accent);"' : ''}>
                        <div class="leaderboard-rank ${rankClass}">${entry.rank}</div>
                        <div class="leaderboard-name">${GameEngine.escapeHTML(entry.playerName)}
                            <span class="text-muted text-sm">${GameEngine.escapeHTML(entry.klasse)}</span>
                        </div>
                        <div class="leaderboard-score">${Math.round(entry.percent)}%</div>
                    </div>`;
            }).join('');
        } catch (e) {
            console.error('Leaderboard laden fehlgeschlagen:', e);
        }
    }

    // --- KI-Feedback ---
    async requestAIFeedback() {
        try {
            const playerID = Auth.getPlayerID();
            if (!playerID) return;

            // Get session ID from last submitted score
            const sessions = await API.getPlayerSessions(playerID);
            if (!sessions || sessions.length === 0) return;
            const lastSession = sessions[0];

            const feedback = await API.getGameFeedback(playerID, lastSession.id);
            if (!feedback || !feedback.text) return;

            // Show feedback in results view
            let fbContainer = document.getElementById('ai-feedback-result');
            if (!fbContainer) {
                fbContainer = document.createElement('div');
                fbContainer.id = 'ai-feedback-result';
                fbContainer.style.cssText = 'margin-top: 16px; padding: 16px; background: var(--glass-bg, rgba(255,255,255,0.65)); border: var(--glass-border, 1px solid rgba(255,107,107,0.2)); border-radius: var(--radius-sm, 8px); box-shadow: var(--shadow-soft, none);';

                const resultsView = document.getElementById('view-results');
                if (resultsView) {
                    const leaderboard = resultsView.querySelector('.section-title');
                    if (leaderboard) {
                        leaderboard.parentNode.insertBefore(fbContainer, leaderboard);
                    } else {
                        resultsView.appendChild(fbContainer);
                    }
                }
            }

            fbContainer.innerHTML = `
                <div style="font-weight: 700; font-size: 0.85rem; margin-bottom: 8px;">🤖 KI-Lerntipp</div>
                <div style="font-size: 0.85rem; line-height: 1.6;">${GameEngine.escapeHTML(feedback.text)}</div>
                ${feedback.tips && feedback.tips.length > 0 ? feedback.tips.map(t =>
                    '<div style="margin-top: 6px; padding: 6px 10px; background: var(--accent-glow, rgba(255,107,107,0.15)); border-radius: 6px; font-size: 0.82rem;">💡 ' + GameEngine.escapeHTML(t) + '</div>'
                ).join('') : ''}
            `;
        } catch (e) {
            console.log('KI-Feedback konnte nicht geladen werden:', e.message);
        }
    }

    // --- Konfetti ---
    showConfetti() {
        const container = document.createElement('div');
        container.className = 'confetti-container';
        document.body.appendChild(container);

        const colors = ['#ff6b6b', '#22c55e', '#f59e0b', '#fa5252', '#ff8787', '#fbbf24'];
        for (let i = 0; i < 60; i++) {
            const piece = document.createElement('div');
            piece.className = 'confetti-piece';
            piece.style.left = Math.random() * 100 + '%';
            piece.style.backgroundColor = colors[Math.floor(Math.random() * colors.length)];
            piece.style.animationDelay = Math.random() * 1.5 + 's';
            piece.style.animationDuration = (1.5 + Math.random() * 2) + 's';
            container.appendChild(piece);
        }

        setTimeout(() => container.remove(), 4000);
    }

    // --- View Switching ---
    showView(viewID) {
        document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
        const el = document.getElementById(viewID);
        if (el) el.classList.add('active');
    }

    showError(message) {
        const el = document.getElementById('error-message');
        if (el) el.textContent = message;
        this.showView('view-error');
    }

    // --- Static Utilities ---
    static shuffleArray(arr) {
        for (let i = arr.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [arr[i], arr[j]] = [arr[j], arr[i]];
        }
        return arr;
    }

    static escapeHTML(str) {
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }
}
