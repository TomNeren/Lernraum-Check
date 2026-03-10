import Vapor
import Fluent

struct PlayerController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let players = routes.grouped("api", "players")

        players.post("login", use: login)
        players.get(":playerID", use: getPlayer)
        players.get(":playerID", "stats", use: getStats)
        players.get("klasse", ":klasse", use: getByKlasse)
    }

    // POST /api/players/login — Erstellt oder findet Spieler
    @Sendable
    func login(req: Request) async throws -> Player {
        let input = try req.content.decode(LoginRequest.self)

        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKlasse = input.klasse.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedKlasse.isEmpty else {
            throw Abort(.badRequest, reason: "Name und Klasse dürfen nicht leer sein.")
        }

        // Existierenden Spieler suchen (Name + Klasse)
        if let existing = try await Player.query(on: req.db)
            .filter(\.$name == trimmedName)
            .filter(\.$klasse == trimmedKlasse)
            .first() {
            existing.lastSeen = Date()
            try await existing.save(on: req.db)
            return existing
        }

        // Neuen Spieler anlegen
        let player = Player(name: trimmedName, klasse: trimmedKlasse)
        try await player.save(on: req.db)
        return player
    }

    // GET /api/players/:playerID
    @Sendable
    func getPlayer(req: Request) async throws -> Player {
        guard let player = try await Player.find(req.parameters.get("playerID"), on: req.db) else {
            throw Abort(.notFound, reason: "Spieler nicht gefunden.")
        }
        return player
    }

    // GET /api/players/:playerID/stats
    @Sendable
    func getStats(req: Request) async throws -> PlayerStats {
        guard let player = try await Player.find(req.parameters.get("playerID"), on: req.db) else {
            throw Abort(.notFound)
        }

        let sessions = try await GameSession.query(on: req.db)
            .filter(\.$player.$id == player.id!)
            .sort(\.$completedAt, .descending)
            .all()

        let totalScore = sessions.reduce(0) { $0 + $1.score }
        let totalMax = sessions.reduce(0) { $0 + $1.maxScore }
        let avgPercent = totalMax > 0 ? Double(totalScore) / Double(totalMax) * 100 : 0

        return PlayerStats(
            player: player,
            totalGames: sessions.count,
            totalScore: totalScore,
            averagePercent: avgPercent,
            recentSessions: Array(sessions.prefix(10))
        )
    }

    // GET /api/players/klasse/:klasse — Alle Spieler einer Klasse
    @Sendable
    func getByKlasse(req: Request) async throws -> [Player] {
        guard let klasse = req.parameters.get("klasse") else {
            throw Abort(.badRequest)
        }
        return try await Player.query(on: req.db)
            .filter(\.$klasse == klasse)
            .sort(\.$name)
            .all()
    }
}
