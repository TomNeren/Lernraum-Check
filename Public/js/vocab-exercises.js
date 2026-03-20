/**
 * LernHub — AI Vocab Exercise Renderer
 */
const VocabExercises = {
    currentType: null,
    currentTopic: null,
    currentPlayer: null,
    exerciseData: null,
    answers: [],

    async start(type, topic, player) {
        this.currentType = type;
        this.currentTopic = topic;
        this.currentPlayer = player;
        this.answers = [];

        const modal = document.getElementById('exercise-modal');
        modal.style.display = '';
        document.getElementById('exercise-loading').style.display = '';
        document.getElementById('exercise-content').style.display = 'none';
        document.getElementById('exercise-result').style.display = 'none';

        const titles = {
            dialogue: 'Dialog-Übung',
            progressive: 'Wort-Entdecker',
            context: 'Lückentext'
        };
        document.getElementById('exercise-title').textContent = titles[type] || 'Übung';
        document.getElementById('exercise-subtitle').textContent = topic;

        try {
            const res = await API.request('POST', '/api/vocab-exercise/generate', {
                topic: topic,
                exerciseType: type,
                difficulty: 2
            });

            this.exerciseData = res;

            // Parse the AI content (it's a JSON string)
            let content;
            try {
                // Try to extract JSON from the response
                const jsonMatch = res.content.match(/\{[\s\S]*\}/);
                content = jsonMatch ? JSON.parse(jsonMatch[0]) : JSON.parse(res.content);
            } catch (e) {
                // If JSON parsing fails, show the raw text
                document.getElementById('exercise-loading').style.display = 'none';
                document.getElementById('exercise-content').style.display = '';
                document.getElementById('exercise-content').innerHTML = `
                    <div class="glass-panel">
                        <div style="white-space: pre-wrap; font-size: 0.9rem; line-height: 1.6;">
                            ${escapeHtml(res.content)}
                        </div>
                    </div>`;
                return;
            }

            document.getElementById('exercise-loading').style.display = 'none';
            document.getElementById('exercise-content').style.display = '';

            switch (type) {
                case 'dialogue': this.renderDialogue(content); break;
                case 'progressive': this.renderProgressive(content); break;
                case 'context': this.renderContext(content); break;
            }
        } catch (e) {
            document.getElementById('exercise-loading').innerHTML = `
                <div style="color: var(--danger); text-align: center; padding: 20px;">
                    Fehler: ${escapeHtml(e.message)}
                </div>
                <button class="btn btn-secondary mt-16" onclick="closeExercise()">Zurück</button>`;
        }
    },

    // --- Dialogue Exercise ---
    renderDialogue(data) {
        const container = document.getElementById('exercise-content');
        if (!data.lines || data.lines.length === 0) {
            container.innerHTML = '<div class="glass-panel text-center text-muted">Keine Übung generiert.</div>';
            return;
        }

        let html = `<div class="glass-panel" style="margin-bottom: 16px;"><h3 style="margin-bottom: 12px;">${escapeHtml(data.title || 'Dialog')}</h3>`;

        data.lines.forEach((line, i) => {
            const speaker = line.speaker || '?';
            if (line.blank) {
                // Line with blank
                const textParts = line.text.split('___');
                html += `<div style="margin-bottom: 12px; padding: 10px; background: var(--bg-secondary); border-radius: var(--radius-sm);">
                    <strong>${escapeHtml(speaker)}:</strong> ${escapeHtml(textParts[0] || '')}`;

                html += `<span id="dialogue-blank-${i}" style="display: inline-block; min-width: 80px; border-bottom: 2px solid var(--accent); text-align: center; font-weight: 600; color: var(--accent); margin: 0 4px;">___</span>`;

                html += `${escapeHtml(textParts[1] || '')}
                    <div style="margin-top: 8px; display: flex; gap: 6px; flex-wrap: wrap;" id="dialogue-options-${i}">`;

                (line.options || []).forEach((opt, j) => {
                    html += `<button class="chip" onclick="VocabExercises.selectDialogueOption(${i}, ${j}, '${escapeAttr(opt)}', ${line.correctIndex})">${escapeHtml(opt)}</button>`;
                });

                html += `</div></div>`;
            } else {
                html += `<div style="margin-bottom: 8px; padding: 8px 10px;">
                    <strong>${escapeHtml(speaker)}:</strong> ${escapeHtml(line.text)}
                </div>`;
            }
        });

        html += `</div>
            <button class="btn btn-primary" id="dialogue-submit-btn" onclick="VocabExercises.submitDialogue()" style="display: none;">Ergebnis anzeigen</button>`;

        container.innerHTML = html;
        this._dialogueData = data;
        this._dialogueAnswered = 0;
        this._dialogueBlanks = data.lines.filter(l => l.blank).length;
    },

    selectDialogueOption(lineIndex, optionIndex, answer, correctIndex) {
        const blank = document.getElementById(`dialogue-blank-${lineIndex}`);
        const options = document.getElementById(`dialogue-options-${lineIndex}`);

        if (blank.dataset.answered) return;
        blank.dataset.answered = 'true';

        const isCorrect = optionIndex === correctIndex;
        blank.textContent = answer;
        blank.style.color = isCorrect ? 'var(--success)' : 'var(--danger)';
        blank.style.borderColor = isCorrect ? 'var(--success)' : 'var(--danger)';

        // Disable all options for this line
        options.querySelectorAll('.chip').forEach((btn, j) => {
            btn.style.pointerEvents = 'none';
            if (j === correctIndex) {
                btn.style.borderColor = 'var(--success)';
                btn.style.background = 'var(--success-bg)';
            } else if (j === optionIndex && !isCorrect) {
                btn.style.borderColor = 'var(--danger)';
                btn.style.background = 'var(--danger-bg)';
            }
        });

        this.answers.push({ expected: this._dialogueData.lines[lineIndex].blank, given: answer, correct: isCorrect });

        this._dialogueAnswered++;
        if (this._dialogueAnswered >= this._dialogueBlanks) {
            document.getElementById('dialogue-submit-btn').style.display = '';
        }
    },

    async submitDialogue() {
        const correct = this.answers.filter(a => a.correct).length;
        await this.showResult(correct, this.answers.length);
    },

    // --- Progressive Exercise ---
    renderProgressive(data) {
        const container = document.getElementById('exercise-content');
        if (!data.words || data.words.length === 0) {
            container.innerHTML = '<div class="glass-panel text-center text-muted">Keine Übung generiert.</div>';
            return;
        }

        this._progWords = data.words;
        this._progIndex = 0;
        this._progStage = 1; // 1=hint2+options, 2=hint1+type, 3=no hint+type
        this.renderProgressiveWord(container);
    },

    renderProgressiveWord(container) {
        if (!container) container = document.getElementById('exercise-content');
        const word = this._progWords[this._progIndex];
        if (!word) {
            const correct = this.answers.filter(a => a.correct).length;
            this.showResult(correct, this.answers.length);
            return;
        }

        const stage = this._progStage;
        const progress = `${this._progIndex + 1}/${this._progWords.length}`;
        let hint = '';
        if (stage === 1) hint = word.hint2 || word.english.substring(0, 2);
        else if (stage === 2) hint = word.hint1 || word.english.substring(0, 1);

        let html = `
            <div class="glass-panel" style="margin-bottom: 16px; text-align: center;">
                <div class="text-muted text-sm" style="margin-bottom: 8px;">Wort ${progress} — Stufe ${stage}/3</div>
                <div style="font-size: 1.2rem; font-weight: 600; margin-bottom: 4px;">${escapeHtml(word.german)}</div>
                ${hint ? `<div style="font-family: monospace; font-size: 1.5rem; color: var(--accent); margin: 12px 0; letter-spacing: 4px;">${escapeHtml(hint)}${'_'.repeat(Math.max(0, word.english.length - hint.length))}</div>` : '<div style="font-family: monospace; font-size: 1.5rem; color: var(--text-muted); margin: 12px 0;">?</div>'}
            </div>`;

        if (stage === 1 && word.options) {
            // Multiple choice
            html += `<div style="display: flex; flex-direction: column; gap: 8px;">`;
            word.options.forEach((opt, i) => {
                html += `<button class="chip" style="width: 100%; justify-content: center; padding: 14px;"
                    onclick="VocabExercises.checkProgressiveChoice('${escapeAttr(opt)}', '${escapeAttr(word.english)}')">${escapeHtml(opt)}</button>`;
            });
            html += `</div>`;
        } else {
            // Free text input
            html += `
                <div style="display: flex; gap: 8px;">
                    <input type="text" id="prog-input" placeholder="Englisches Wort eingeben..." autocomplete="off"
                        style="flex: 1; padding: 12px 16px; background: rgba(255,255,255,0.5); border: var(--glass-border); border-radius: var(--radius-sm); font-family: var(--font-sans); font-size: 1rem; color: var(--text-primary);"
                        onkeydown="if(event.key==='Enter')VocabExercises.checkProgressiveInput('${escapeAttr(word.english)}')">
                    <button class="btn btn-primary" style="width: auto; padding: 12px 20px;"
                        onclick="VocabExercises.checkProgressiveInput('${escapeAttr(word.english)}')">OK</button>
                </div>`;
        }

        container.innerHTML = html;

        // Focus input if present
        const input = document.getElementById('prog-input');
        if (input) setTimeout(() => input.focus(), 100);
    },

    checkProgressiveChoice(given, expected) {
        const correct = given.toLowerCase().trim() === expected.toLowerCase().trim();
        this.answers.push({ expected, given, correct });
        this.advanceProgressive();
    },

    checkProgressiveInput(expected) {
        const input = document.getElementById('prog-input');
        const given = (input ? input.value : '').trim();
        if (!given) return;

        const correct = given.toLowerCase() === expected.toLowerCase();
        this.answers.push({ expected, given, correct });

        // Show brief feedback
        if (input) {
            input.style.borderColor = correct ? 'var(--success)' : 'var(--danger)';
            input.style.color = correct ? 'var(--success)' : 'var(--danger)';
            if (!correct) input.value = expected;
        }

        setTimeout(() => this.advanceProgressive(), correct ? 300 : 1200);
    },

    advanceProgressive() {
        this._progStage++;
        if (this._progStage > 3) {
            this._progStage = 1;
            this._progIndex++;
        }
        this.renderProgressiveWord();
    },

    // --- Context Exercise ---
    renderContext(data) {
        const container = document.getElementById('exercise-content');
        if (!data.text || !data.blanks) {
            container.innerHTML = '<div class="glass-panel text-center text-muted">Keine Übung generiert.</div>';
            return;
        }

        this._contextData = data;

        // Replace {0}, {1}, etc. with input fields
        let textHtml = escapeHtml(data.text);
        data.blanks.forEach((blank, i) => {
            const marker = `{${blank.index !== undefined ? blank.index : i}}`;
            const input = `<span style="display: inline-block; margin: 2px 4px;">
                <input type="text" id="context-blank-${i}" placeholder="${escapeAttr(blank.german)}"
                    autocomplete="off"
                    style="width: ${Math.max(80, blank.answer.length * 12)}px; padding: 4px 8px; border: 2px solid var(--accent); border-radius: 4px; font-family: var(--font-sans); font-size: 0.9rem; text-align: center; background: var(--accent-glow);">
            </span>`;
            textHtml = textHtml.replace(escapeHtml(marker), input);
        });

        container.innerHTML = `
            <div class="glass-panel" style="margin-bottom: 16px;">
                <h3 style="margin-bottom: 12px;">${escapeHtml(data.title || 'Lückentext')}</h3>
                <div style="line-height: 2; font-size: 1rem;">${textHtml}</div>
            </div>
            <button class="btn btn-primary" onclick="VocabExercises.submitContext()">Überprüfen</button>`;
    },

    submitContext() {
        const data = this._contextData;
        this.answers = [];

        data.blanks.forEach((blank, i) => {
            const input = document.getElementById(`context-blank-${i}`);
            const given = input ? input.value.trim() : '';
            const correct = given.toLowerCase() === blank.answer.toLowerCase();

            this.answers.push({ expected: blank.answer, given, correct });

            if (input) {
                input.style.borderColor = correct ? 'var(--success)' : 'var(--danger)';
                input.style.color = correct ? 'var(--success)' : 'var(--danger)';
                input.disabled = true;
                if (!correct) {
                    input.value = blank.answer;
                    input.style.background = 'var(--danger-bg)';
                } else {
                    input.style.background = 'var(--success-bg)';
                }
            }
        });

        const correctCount = this.answers.filter(a => a.correct).length;

        setTimeout(() => this.showResult(correctCount, this.answers.length), 1500);
    },

    // --- Results ---
    async showResult(correctCount, total) {
        document.getElementById('exercise-content').style.display = 'none';
        const resultDiv = document.getElementById('exercise-result');
        resultDiv.style.display = '';

        const percent = total > 0 ? Math.round(correctCount / total * 100) : 0;
        const color = percent >= 80 ? 'var(--success)' : percent >= 50 ? 'var(--warning)' : 'var(--danger)';

        resultDiv.innerHTML = `
            <div class="glass-panel text-center" style="margin-bottom: 16px;">
                <div style="font-size: 3rem; font-weight: 700; color: ${color};">${percent}%</div>
                <div class="text-muted">${correctCount} von ${total} richtig</div>
            </div>
            <div id="ai-feedback-area" class="glass-panel" style="margin-bottom: 16px;">
                <div class="text-muted text-sm text-center">KI-Feedback wird geladen...</div>
            </div>
            <div style="display: flex; gap: 8px;">
                <button class="btn btn-secondary" onclick="closeExercise()" style="flex: 1;">Zurück</button>
                <button class="btn btn-primary" onclick="VocabExercises.start(VocabExercises.currentType, VocabExercises.currentTopic, VocabExercises.currentPlayer)" style="flex: 1;">Nochmal</button>
            </div>`;

        // Get AI feedback
        try {
            const wrong = this.answers.filter(a => !a.correct).map(a => ({ expected: a.expected, given: a.given }));
            const feedback = await API.request('POST', '/api/vocab-exercise/submit', {
                playerID: this.currentPlayer.id,
                exerciseType: this.currentType,
                topic: this.currentTopic,
                correctCount,
                totalCount: total,
                wrongAnswers: wrong
            });

            document.getElementById('ai-feedback-area').innerHTML = `
                <div style="font-size: 0.9rem; line-height: 1.6;">${escapeHtml(feedback.feedback)}</div>`;
        } catch (e) {
            document.getElementById('ai-feedback-area').innerHTML = `
                <div class="text-muted text-sm text-center">Feedback nicht verfügbar</div>`;
        }
    }
};

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function escapeAttr(text) {
    if (!text) return '';
    return text.replace(/'/g, "\\'").replace(/"/g, '&quot;');
}
