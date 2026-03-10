/**
 * LernSpiel Auth — Player State Management
 * Speichert Player-Daten in sessionStorage (verschwindet beim Tab-Schließen)
 */

const Auth = {
    STORAGE_KEY: 'lernspiel_player',

    // Aktuellen Player aus Session holen
    getPlayer() {
        const stored = sessionStorage.getItem(this.STORAGE_KEY);
        return stored ? JSON.parse(stored) : null;
    },

    // Player nach Login speichern
    setPlayer(player) {
        sessionStorage.setItem(this.STORAGE_KEY, JSON.stringify(player));
    },

    // Ausloggen
    logout() {
        sessionStorage.removeItem(this.STORAGE_KEY);
    },

    // Prüfen ob eingeloggt
    isLoggedIn() {
        return this.getPlayer() !== null;
    },

    // Player-ID holen (oder null)
    getPlayerID() {
        const player = this.getPlayer();
        return player ? player.id : null;
    },

    // Player-Name holen
    getPlayerName() {
        const player = this.getPlayer();
        return player ? player.name : '';
    },

    // Klasse holen
    getKlasse() {
        const player = this.getPlayer();
        return player ? player.klasse : '';
    },

    // Raum speichern
    setRaum(raum) {
        sessionStorage.setItem('currentRaum', raum);
    },

    // Raum holen
    getRaum() {
        return sessionStorage.getItem('currentRaum');
    },

    // Redirect zu Login wenn nicht eingeloggt
    requireLogin() {
        if (!this.isLoggedIn()) {
            window.location.href = '/index.html';
            return false;
        }
        return true;
    }
};
