/**
 * LernSpiel API Client
 * Gemeinsamer Fetch-Wrapper für alle Module
 */

const API = {
    base: '', // Gleicher Server — relativ

    async request(method, path, body = null) {
        const opts = {
            method,
            headers: { 'Content-Type': 'application/json' },
        };
        if (body) opts.body = JSON.stringify(body);

        const res = await fetch(`${this.base}${path}`, opts);

        if (!res.ok) {
            const error = await res.json().catch(() => ({ reason: res.statusText }));
            throw new Error(error.reason || `HTTP ${res.status}`);
        }

        const text = await res.text();
        if (!text) return {};
        try { return JSON.parse(text); } catch { return {}; }
    },

    // --- Player ---
    async login(name, klasse) {
        return this.request('POST', '/api/players/login', { name, klasse });
    },

    async getPlayerStats(playerID) {
        return this.request('GET', `/api/players/${playerID}/stats`);
    },

    // --- Games ---
    async listGames() {
        return this.request('GET', '/api/games');
    },

    async getGame(gameID) {
        return this.request('GET', `/api/games/${gameID}`);
    },

    async createGame(data) {
        return this.request('POST', '/api/games', data);
    },

    // --- Sessions ---
    async submitScore(data) {
        return this.request('POST', '/api/sessions', data);
    },

    async getLeaderboard(moduleID) {
        return this.request('GET', `/api/sessions/module/${moduleID}/leaderboard`);
    },

    async getPlayerSessions(playerID) {
        return this.request('GET', `/api/sessions/player/${playerID}`);
    },

    // --- Lernraum ---
    async checkinLernraum(playerID, raum) {
        return this.request('POST', '/api/lernraum/checkin', { playerID, raum });
    },

    async updateLernraum(playerID, raum) {
        return this.request('PUT', '/api/lernraum/update', { playerID, raum });
    },

    async checkoutLernraum(playerID) {
        return this.request('POST', '/api/lernraum/checkout', { playerID });
    },

    async getAktiveLernraeume() {
        return this.request('GET', '/api/lernraum/aktiv');
    },

    async getAktiveLernraeumeKlasse(klasse) {
        return this.request('GET', `/api/lernraum/aktiv/${encodeURIComponent(klasse)}`);
    },

    async getLernraumHistory(playerID) {
        return this.request('GET', `/api/lernraum/history/${playerID}`);
    },

    // --- Vocab SRS ---
    async importVocab(topic, items) {
        return this.request('POST', '/api/vocab/import', { topic, items });
    },

    async getDueVocab(playerID) {
        return this.request('GET', `/api/vocab/due/${playerID}`);
    },

    async reviewVocab(playerID, vocabID, quality) {
        return this.request('POST', '/api/vocab/review', { playerID, vocabID, quality });
    },

    async getVocabStats(playerID) {
        return this.request('GET', `/api/vocab/stats/${playerID}`);
    },

    async getVocabTopics() {
        return this.request('GET', '/api/vocab/topics');
    },

    // --- Personal Tasks ---
    async getPersonalTasks(playerID) {
        return this.request('GET', `/api/personal/${playerID}`);
    },

    async getAllPersonalTasks(playerID) {
        return this.request('GET', `/api/personal/${playerID}/all`);
    },

    async assignTask(data) {
        return this.request('POST', '/api/personal/assign', data);
    },

    async completeTask(taskID) {
        return this.request('POST', `/api/personal/${taskID}/complete`);
    },

    // --- Admin ---
    async adminLogin(password) {
        return this.request('POST', '/api/admin/login', { password });
    },

    async adminOverview() {
        return this.request('GET', '/api/admin/overview');
    },

    async adminStudents() {
        return this.request('GET', '/api/admin/students');
    },

    async adminStudentDetail(playerID) {
        return this.request('GET', `/api/admin/students/${playerID}/detail`);
    },

    async adminKlassen() {
        return this.request('GET', '/api/admin/klassen');
    },

    async adminDeleteGame(gameID) {
        return this.request('DELETE', `/api/admin/games/${gameID}`);
    },

    async adminDeleteStudent(playerID) {
        return this.request('DELETE', `/api/admin/students/${playerID}`);
    },

    async adminForceCheckout(playerID) {
        return this.request('POST', `/api/admin/students/${playerID}/checkout`);
    },

    async adminForceCheckoutAll() {
        return this.request('POST', '/api/admin/checkout-all');
    },

    // --- Lesson Codes / Klassen ---
    async getJoinInfo(code) {
        return this.request('GET', `/api/join/${encodeURIComponent(code)}`);
    },

    async checkinWithCode(code, playerID) {
        return this.request('POST', `/api/join/${encodeURIComponent(code)}/checkin`, { playerID });
    },

    async adminCreateKlasse(name) {
        return this.request('POST', '/api/admin/klassen/create', { name });
    },

    async adminListKlassen() {
        return this.request('GET', '/api/admin/klassen/list');
    },

    async adminKlasseDetail(klasseID) {
        return this.request('GET', `/api/admin/klassen/${klasseID}/detail`);
    },

    async adminAddStudents(klasseID, names) {
        return this.request('POST', `/api/admin/klassen/${klasseID}/students`, { names });
    },

    async adminDeleteKlasse(klasseID) {
        return this.request('DELETE', `/api/admin/klassen/${klasseID}`);
    },

    async adminRemoveStudent(klasseID, playerID) {
        return this.request('DELETE', `/api/admin/klassen/${klasseID}/students/${playerID}`);
    },

    async adminStartLesson(klasseID, durationMinutes) {
        return this.request('POST', `/api/admin/klassen/${klasseID}/start-lesson`, { durationMinutes: durationMinutes || 90 });
    },

    async adminStopLesson(klasseID) {
        return this.request('POST', `/api/admin/klassen/${klasseID}/stop-lesson`);
    },

    // --- Admin: Vocab Management ---
    async adminVocabTopics() {
        return this.request('GET', '/api/admin/vocab/topics');
    },

    async adminVocabTopicItems(topicName) {
        return this.request('GET', `/api/admin/vocab/topic/${encodeURIComponent(topicName)}`);
    },

    async adminUpdateVocabItem(vocabID, data) {
        return this.request('PUT', `/api/admin/vocab/items/${vocabID}`, data);
    },

    async adminDeleteVocabItem(vocabID) {
        return this.request('DELETE', `/api/admin/vocab/items/${vocabID}`);
    },

    async adminDeleteVocabTopic(topicName) {
        return this.request('DELETE', `/api/admin/vocab/topic/${encodeURIComponent(topicName)}`);
    },

    // --- Content Assignments ---
    async adminAssignContent(contentType, contentValue, klasse, playerID) {
        return this.request('POST', '/api/admin/assign', { contentType, contentValue, klasse, playerID: playerID || undefined });
    },

    async adminRemoveAssignment(assignmentID) {
        return this.request('DELETE', `/api/admin/assign/${assignmentID}`);
    },

    async adminGetGameAssignments(gameID) {
        return this.request('GET', `/api/admin/assign/game/${gameID}`);
    },

    async adminGetVocabTopicAssignments(topicName) {
        return this.request('GET', `/api/admin/assign/vocab-topic/${encodeURIComponent(topicName)}`);
    },

    // --- Player-specific game list ---
    async listGamesForPlayer(playerID) {
        return this.request('GET', `/api/games/for/${playerID}`);
    },

    // --- Chat ---
    async sendChatMessage(playerID, message) {
        return this.request('POST', '/api/chat/send', { playerID, message });
    },

    async getMyChatMessages(playerID) {
        return this.request('GET', `/api/chat/my/${playerID}`);
    },

    async getAllChatMessages() {
        return this.request('GET', '/api/chat/all');
    },

    async getChatMessagesByKlasse(klasse) {
        return this.request('GET', `/api/chat/klasse/${encodeURIComponent(klasse)}`);
    },

    async getUnreadChatCount() {
        return this.request('GET', '/api/chat/unread');
    },

    async markChatRead(messageID) {
        return this.request('PUT', `/api/chat/${messageID}/read`);
    },

    async markAllChatRead() {
        return this.request('POST', '/api/chat/read-all');
    },

    // --- Health ---
    async health() {
        return this.request('GET', '/api/health');
    }
};
