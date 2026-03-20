import Vapor
import Fluent

struct LernraumController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let lernraum = routes.grouped("api", "lernraum")

        lernraum.post("checkin", use: checkin)
        lernraum.put("update", use: updateRaum)
        lernraum.post("checkout", use: checkout)
        lernraum.get("aktiv", use: getAktive)
        lernraum.get("aktiv", ":klasse", use: getAktiveByKlasse)
        lernraum.get("history", ":playerID", use: getHistory)
    }

    // POST /api/lernraum/checkin
    @Sendable
    func checkin(req: Request) async throws -> LernraumCheckin {
        let input = try req.content.decode(CheckinRequest.self)

        // Spieler muss existieren
        guard try await Player.find(input.playerID, on: req.db) != nil else {
            throw Abort(.notFound, reason: "Spieler nicht gefunden. Bitte neu anmelden.")
        }

        // Bestehenden aktiven Check-in schließen
        if let aktiv = try await LernraumCheckin.query(on: req.db)
            .filter(\.$player.$id == input.playerID)
            .filter(\.$checkedOutAt == nil)
            .first() {
            aktiv.checkedOutAt = Date()
            try await aktiv.save(on: req.db)
        }

        let checkin = LernraumCheckin(playerID: input.playerID, raum: input.raum)
        try await checkin.save(on: req.db)
        return checkin
    }

    // PUT /api/lernraum/update
    @Sendable
    func updateRaum(req: Request) async throws -> LernraumCheckin {
        let input = try req.content.decode(CheckinRequest.self)

        // Spieler muss existieren
        guard try await Player.find(input.playerID, on: req.db) != nil else {
            throw Abort(.notFound, reason: "Spieler nicht gefunden. Bitte neu anmelden.")
        }

        // Aktuellen Check-in schließen
        if let aktiv = try await LernraumCheckin.query(on: req.db)
            .filter(\.$player.$id == input.playerID)
            .filter(\.$checkedOutAt == nil)
            .first() {
            aktiv.checkedOutAt = Date()
            try await aktiv.save(on: req.db)
        }

        // Neuen erstellen
        let checkin = LernraumCheckin(playerID: input.playerID, raum: input.raum)
        try await checkin.save(on: req.db)
        return checkin
    }

    // POST /api/lernraum/checkout
    @Sendable
    func checkout(req: Request) async throws -> HTTPStatus {
        let input = try req.content.decode(CheckoutRequest.self)

        guard let aktiv = try await LernraumCheckin.query(on: req.db)
            .filter(\.$player.$id == input.playerID)
            .filter(\.$checkedOutAt == nil)
            .first() else {
            throw Abort(.notFound, reason: "Kein aktiver Check-in gefunden.")
        }

        aktiv.checkedOutAt = Date()
        try await aktiv.save(on: req.db)
        return .ok
    }

    // GET /api/lernraum/aktiv
    @Sendable
    func getAktive(req: Request) async throws -> [AktivCheckin] {
        let checkins = try await LernraumCheckin.query(on: req.db)
            .filter(\.$checkedOutAt == nil)
            .with(\.$player)
            .all()

        return checkins.map { checkin in
            AktivCheckin(
                id: checkin.id!,
                playerName: checkin.player.name,
                klasse: checkin.player.klasse,
                raum: checkin.raum,
                checkedInAt: checkin.checkedInAt
            )
        }
    }

    // GET /api/lernraum/aktiv/:klasse
    @Sendable
    func getAktiveByKlasse(req: Request) async throws -> [AktivCheckin] {
        guard let klasse = req.parameters.get("klasse") else {
            throw Abort(.badRequest)
        }

        let checkins = try await LernraumCheckin.query(on: req.db)
            .filter(\.$checkedOutAt == nil)
            .with(\.$player)
            .all()
            .filter { $0.player.klasse == klasse }

        return checkins.map { checkin in
            AktivCheckin(
                id: checkin.id!,
                playerName: checkin.player.name,
                klasse: checkin.player.klasse,
                raum: checkin.raum,
                checkedInAt: checkin.checkedInAt
            )
        }
    }

    // GET /api/lernraum/history/:playerID
    @Sendable
    func getHistory(req: Request) async throws -> [LernraumCheckin] {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        return try await LernraumCheckin.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .sort(\.$checkedInAt, .descending)
            .range(..<50)
            .all()
    }
}
