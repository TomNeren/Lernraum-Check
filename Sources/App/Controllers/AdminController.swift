import Vapor
import Fluent

struct AdminController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let admin = routes.grouped("api", "admin")

        admin.post("login", use: login)
        admin.get("overview", use: getOverview)
        admin.get("students", use: getAllStudents)
        admin.get("students", ":playerID", "detail", use: getStudentDetail)
        admin.get("klassen", use: getKlassen)
        admin.delete("games", ":gameID", use: deleteGame)
        admin.delete("students", ":playerID", use: deleteStudent)
        admin.post("students", ":playerID", "checkout", use: forceCheckout)
        admin.post("checkout-all", use: forceCheckoutAll)
    }

    // POST /api/admin/login
    @Sendable
    func login(req: Request) async throws -> AdminLoginResponse {
        let input = try req.content.decode(AdminLoginRequest.self)
        let adminPassword = Environment.get("ADMIN_PASSWORD") ?? "lernspiel2026"

        guard input.password == adminPassword else {
            throw Abort(.unauthorized, reason: "Falsches Passwort.")
        }

        // Einfacher Token (Hash aus Passwort + Datum)
        let token = Data((adminPassword + Date().description).utf8).base64EncodedString()
        return AdminLoginResponse(token: token, message: "Erfolgreich angemeldet.")
    }

    // GET /api/admin/overview
    @Sendable
    func getOverview(req: Request) async throws -> AdminOverview {
        let players = try await Player.query(on: req.db).all()
        let games = try await GameModule.query(on: req.db).all()
        let sessions = try await GameSession.query(on: req.db).all()
        let activeCheckins = try await LernraumCheckin.query(on: req.db)
            .filter(\.$checkedOutAt == nil)
            .with(\.$player)
            .all()
        let vocabItems = try await VocabItem.query(on: req.db).count()

        // Klassen aufschlüsseln
        let klassenSet = Set(players.map { $0.klasse })
        let klassen = klassenSet.sorted()

        return AdminOverview(
            totalStudents: players.count,
            totalGames: games.count,
            totalSessions: sessions.count,
            totalVocabItems: vocabItems,
            klassen: klassen,
            activeCheckins: activeCheckins.map { checkin in
                AktivCheckin(
                    id: checkin.id!,
                    playerName: checkin.player.name,
                    klasse: checkin.player.klasse,
                    raum: checkin.raum,
                    checkedInAt: checkin.checkedInAt
                )
            }
        )
    }

    // GET /api/admin/students
    @Sendable
    func getAllStudents(req: Request) async throws -> [StudentOverview] {
        let players = try await Player.query(on: req.db)
            .with(\.$sessions) { $0.with(\.$module) }
            .sort(\.$klasse)
            .sort(\.$name)
            .all()

        // Aktive Check-ins
        let activeCheckins = try await LernraumCheckin.query(on: req.db)
            .filter(\.$checkedOutAt == nil)
            .all()
        let checkinByPlayer = Dictionary(grouping: activeCheckins, by: { $0.$player.id })

        return players.map { player in
            let sessions = player.sessions
            let totalScore = sessions.reduce(0) { $0 + $1.score }
            let avgPercent = sessions.isEmpty ? 0.0 :
                sessions.reduce(0.0) { $0 + (Double($1.score) / max(1, Double($1.maxScore)) * 100) } / Double(sessions.count)

            let currentRaum = checkinByPlayer[player.id!]?.first?.raum

            // Letzte Sessions als CompletedGame
            let recentGames = sessions
                .sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }
                .prefix(10)
                .map { session in
                    CompletedGame(
                        gameTitle: session.module.title,
                        gameType: session.module.type,
                        score: session.score,
                        maxScore: session.maxScore,
                        percent: session.maxScore > 0 ? Double(session.score) / Double(session.maxScore) * 100 : 0,
                        completedAt: session.completedAt
                    )
                }

            return StudentOverview(
                id: player.id!,
                name: player.name,
                klasse: player.klasse,
                currentRaum: currentRaum,
                totalGames: sessions.count,
                totalScore: totalScore,
                averagePercent: round(avgPercent * 10) / 10,
                lastSeen: player.lastSeen,
                recentGames: Array(recentGames)
            )
        }
    }

    // GET /api/admin/students/:playerID/detail
    @Sendable
    func getStudentDetail(req: Request) async throws -> StudentDetail {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        let query = Player.query(on: req.db)
            .filter(\.$id == playerID)
            .with(\.$sessions) { $0.with(\.$module) }

        guard let player = try await query.first() else {
            throw Abort(.notFound, reason: "Schüler nicht gefunden.")
        }

        // Vocab Stats
        let vocabProgress = try await VocabProgress.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .all()

        var vocabBoxes = [0, 0, 0, 0, 0]
        var vocabDue = 0
        let now = Date()
        for p in vocabProgress {
            let idx = max(0, min(4, p.box - 1))
            vocabBoxes[idx] += 1
            if p.nextReview <= now { vocabDue += 1 }
        }

        // Aktiver Raum
        let activeCheckin = try await LernraumCheckin.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .filter(\.$checkedOutAt == nil)
            .first()

        // Personal Tasks
        let openTasks = try await PersonalTask.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .filter(\.$completed == false)
            .count()
        let completedTasks = try await PersonalTask.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .filter(\.$completed == true)
            .count()

        let sessions = player.sessions
        let sortedSessions = sessions.sorted {
            ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast)
        }
        var allGames: [CompletedGame] = []
        for session in sortedSessions {
            let pct = session.maxScore > 0 ? Double(session.score) / Double(session.maxScore) * 100 : 0
            allGames.append(CompletedGame(
                gameTitle: session.module.title,
                gameType: session.module.type,
                score: session.score,
                maxScore: session.maxScore,
                percent: pct,
                completedAt: session.completedAt
            ))
        }

        let totalScore = sessions.reduce(0) { $0 + $1.score }
        let avgPct: Double
        if sessions.isEmpty {
            avgPct = 0
        } else {
            let sum = sessions.reduce(0.0) { $0 + (Double($1.score) / max(1, Double($1.maxScore)) * 100) }
            avgPct = round(sum / Double(sessions.count) * 10) / 10
        }

        return StudentDetail(
            id: player.id!,
            name: player.name,
            klasse: player.klasse,
            currentRaum: activeCheckin?.raum,
            lastSeen: player.lastSeen,
            totalGames: sessions.count,
            totalScore: totalScore,
            averagePercent: avgPct,
            vocabTotal: vocabProgress.count,
            vocabBoxes: vocabBoxes,
            vocabDueToday: vocabDue,
            openTasks: openTasks,
            completedTasks: completedTasks,
            games: allGames
        )
    }

    // GET /api/admin/klassen
    @Sendable
    func getKlassen(req: Request) async throws -> [KlasseOverview] {
        let players = try await Player.query(on: req.db)
            .with(\.$sessions)
            .all()

        let grouped = Dictionary(grouping: players, by: { $0.klasse })

        return grouped.map { (klasse, students) in
            let allSessions = students.flatMap { $0.sessions }
            let totalScore = allSessions.reduce(0.0) { $0 + (Double($1.score) / max(1, Double($1.maxScore)) * 100) }
            let avgScore = allSessions.isEmpty ? 0.0 : totalScore / Double(allSessions.count)

            return KlasseOverview(
                klasse: klasse,
                playerCount: students.count,
                averageScore: round(avgScore * 10) / 10,
                gamesPlayed: allSessions.count
            )
        }.sorted { $0.klasse < $1.klasse }
    }

    // DELETE /api/admin/games/:gameID
    @Sendable
    func deleteGame(req: Request) async throws -> HTTPStatus {
        guard let gameID: UUID = req.parameters.get("gameID") else {
            throw Abort(.badRequest)
        }

        // Erst Sessions löschen, dann Spiel
        try await GameSession.query(on: req.db)
            .filter(\.$module.$id == gameID)
            .delete()

        guard let game = try await GameModule.find(gameID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await game.delete(on: req.db)
        return .ok
    }

    // POST /api/admin/students/:playerID/checkout
    @Sendable
    func forceCheckout(req: Request) async throws -> HTTPStatus {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        let checkins = try await LernraumCheckin.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .filter(\.$checkedOutAt == nil)
            .all()

        for checkin in checkins {
            checkin.checkedOutAt = Date()
            try await checkin.save(on: req.db)
        }
        return .ok
    }

    // POST /api/admin/checkout-all
    @Sendable
    func forceCheckoutAll(req: Request) async throws -> ForceCheckoutAllResponse {
        let checkins = try await LernraumCheckin.query(on: req.db)
            .filter(\.$checkedOutAt == nil)
            .all()

        for checkin in checkins {
            checkin.checkedOutAt = Date()
            try await checkin.save(on: req.db)
        }
        return ForceCheckoutAllResponse(checkedOut: checkins.count)
    }

    // DELETE /api/admin/students/:playerID
    @Sendable
    func deleteStudent(req: Request) async throws -> HTTPStatus {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        // Abhängige Daten löschen
        try await GameSession.query(on: req.db).filter(\.$player.$id == playerID).delete()
        try await LernraumCheckin.query(on: req.db).filter(\.$player.$id == playerID).delete()
        try await VocabProgress.query(on: req.db).filter(\.$player.$id == playerID).delete()
        try await PersonalTask.query(on: req.db).filter(\.$player.$id == playerID).delete()

        guard let player = try await Player.find(playerID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await player.delete(on: req.db)
        return .ok
    }
}
