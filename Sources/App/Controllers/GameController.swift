import Vapor
import Fluent

struct GameController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let games = routes.grouped("api", "games")
        games.get(use: listGames)
        games.get("for", ":playerID", use: listGamesForPlayer)
        games.get(":gameID", use: getGame)

        // Protected: only admin can create games
        let protectedGames = games.grouped(AdminAuthMiddleware())
        protectedGames.post(use: createGame)

        let sessions = routes.grouped("api", "sessions")
        sessions.post(use: submitScore)
        sessions.get("player", ":playerID", use: playerSessions)
        sessions.get("module", ":moduleID", "leaderboard", use: leaderboard)
    }

    // MARK: - Games

    // GET /api/games — Alle Spiele auflisten
    @Sendable
    func listGames(req: Request) async throws -> [GameListItem] {
        let modules = try await GameModule.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .all()

        return modules.map { module in
            GameListItem(
                id: module.id!,
                type: module.type,
                title: module.title,
                kompetenz: module.kompetenz,
                lsNumber: module.lsNumber,
                soloLevel: module.soloLevel,
                questionCount: module.config.questions?.count ?? 0
            )
        }
    }

    // GET /api/games/for/:playerID — Games assigned to this player's class or individually
    @Sendable
    func listGamesForPlayer(req: Request) async throws -> [GameListItem] {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }
        guard let player = try await Player.find(playerID, on: req.db) else {
            throw Abort(.notFound, reason: "Spieler nicht gefunden.")
        }

        // Get assignments for this player's class + individual
        let assignments = try await ContentAssignment.query(on: req.db)
            .filter(\.$contentType == "game")
            .group(.or) { or in
                or.filter(\.$klasse == player.klasse)
                or.filter(\.$playerID == playerID)
            }
            .all()

        // If no assignments exist at all for games, show all games (backwards compatible)
        let allGameAssignments = try await ContentAssignment.query(on: req.db)
            .filter(\.$contentType == "game")
            .count()

        let modules: [GameModule]
        if allGameAssignments == 0 {
            // No assignments configured — show all
            modules = try await GameModule.query(on: req.db).sort(\.$createdAt, .descending).all()
        } else {
            let gameIDs = assignments.compactMap { UUID(uuidString: $0.contentValue) }
            if gameIDs.isEmpty {
                return []
            }
            modules = try await GameModule.query(on: req.db)
                .filter(\.$id ~~ gameIDs)
                .sort(\.$createdAt, .descending)
                .all()
        }

        return modules.map { module in
            GameListItem(
                id: module.id!,
                type: module.type,
                title: module.title,
                kompetenz: module.kompetenz,
                lsNumber: module.lsNumber,
                soloLevel: module.soloLevel,
                questionCount: module.config.questions?.count ?? 0
            )
        }
    }

    // GET /api/games/:gameID — Spiel mit Config (für Frontend)
    @Sendable
    func getGame(req: Request) async throws -> GameModule {
        guard let game = try await GameModule.find(req.parameters.get("gameID"), on: req.db) else {
            throw Abort(.notFound, reason: "Spiel nicht gefunden.")
        }
        return game
    }

    // POST /api/games — Neues Spiel erstellen (Lehrkraft)
    @Sendable
    func createGame(req: Request) async throws -> GameModule {
        let input = try req.content.decode(CreateGameRequest.self)

        let module = GameModule(
            type: input.type,
            title: input.title,
            kompetenz: input.kompetenz,
            lsNumber: input.lsNumber,
            soloLevel: input.soloLevel,
            config: input.config
        )
        try await module.save(on: req.db)
        return module
    }

    // MARK: - Sessions

    // POST /api/sessions — Score einreichen
    @Sendable
    func submitScore(req: Request) async throws -> GameSession {
        let input = try req.content.decode(SubmitScoreRequest.self)

        // Spieler und Modul prüfen
        guard try await Player.find(input.playerID, on: req.db) != nil else {
            throw Abort(.notFound, reason: "Spieler nicht gefunden.")
        }
        guard try await GameModule.find(input.moduleID, on: req.db) != nil else {
            throw Abort(.notFound, reason: "Spiel nicht gefunden.")
        }

        let session = GameSession(
            playerID: input.playerID,
            moduleID: input.moduleID,
            score: input.score,
            maxScore: input.maxScore,
            timeSpent: input.timeSpent,
            details: input.details
        )
        try await session.save(on: req.db)
        return session
    }

    // GET /api/sessions/player/:playerID — Alle Sessions eines Spielers
    @Sendable
    func playerSessions(req: Request) async throws -> [GameSession] {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }
        return try await GameSession.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .with(\.$module)
            .sort(\.$completedAt, .descending)
            .limit(50)
            .all()
    }

    // GET /api/sessions/module/:moduleID/leaderboard
    @Sendable
    func leaderboard(req: Request) async throws -> [LeaderboardEntry] {
        guard let moduleID: UUID = req.parameters.get("moduleID") else {
            throw Abort(.badRequest)
        }

        let sessions = try await GameSession.query(on: req.db)
            .filter(\.$module.$id == moduleID)
            .with(\.$player)
            .sort(\.$score, .descending)
            .all()

        // Bester Score pro Spieler
        var bestByPlayer: [UUID: GameSession] = [:]
        for session in sessions {
            let pid = session.$player.id
            if let existing = bestByPlayer[pid] {
                if session.score > existing.score {
                    bestByPlayer[pid] = session
                }
            } else {
                bestByPlayer[pid] = session
            }
        }

        let sorted = bestByPlayer.values.sorted { $0.score > $1.score }

        return sorted.enumerated().map { index, session in
            LeaderboardEntry(
                rank: index + 1,
                playerName: session.player.name,
                klasse: session.player.klasse,
                score: session.score,
                maxScore: session.maxScore,
                percent: session.maxScore > 0
                    ? Double(session.score) / Double(session.maxScore) * 100 : 0,
                timeSpent: session.timeSpent
            )
        }
    }
}
