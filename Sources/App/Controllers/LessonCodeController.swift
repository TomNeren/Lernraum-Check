import Vapor
import Fluent

struct LessonCodeController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Admin endpoints — protected with admin auth
        let admin = routes.grouped("api", "admin").grouped(AdminAuthMiddleware())
        admin.post("klassen", "create", use: createKlasse)
        admin.get("klassen", "list", use: listKlassen)
        admin.get("klassen", ":klasseID", "detail", use: getKlasseDetail)
        admin.post("klassen", ":klasseID", "students", use: addStudents)
        admin.delete("klassen", ":klasseID", use: deleteKlasse)
        admin.post("klassen", ":klasseID", "start-lesson", use: startLesson)
        admin.post("klassen", ":klasseID", "stop-lesson", use: stopLesson)
        admin.delete("klassen", ":klasseID", "students", ":playerID", use: removeStudent)

        // Public join endpoints
        let join = routes.grouped("api", "join")
        join.get(":code", use: getJoinInfo)
        join.post(":code", "checkin", use: checkinWithCode)
    }

    // MARK: - Admin: Klassen

    // POST /api/admin/klassen/create
    @Sendable
    func createKlasse(req: Request) async throws -> Klasse {
        let input = try req.content.decode(CreateKlasseRequest.self)
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw Abort(.badRequest, reason: "Klassenname darf nicht leer sein.")
        }

        // Check if exists
        if let _ = try await Klasse.query(on: req.db).filter(\.$name == name).first() {
            throw Abort(.conflict, reason: "Klasse '\(name)' existiert bereits.")
        }

        let klasse = Klasse(name: name)
        try await klasse.save(on: req.db)
        return klasse
    }

    // GET /api/admin/klassen/list
    @Sendable
    func listKlassen(req: Request) async throws -> [KlasseListItem] {
        let klassen = try await Klasse.query(on: req.db).sort(\.$name).all()

        var result: [KlasseListItem] = []
        for k in klassen {
            let studentCount = try await Player.query(on: req.db)
                .filter(\.$klasse == k.name)
                .count()
            let hasActiveCode = try await LessonCode.query(on: req.db)
                .filter(\.$klasse.$id == k.id!)
                .filter(\.$active == true)
                .first()
                .map { $0.isValid } ?? false

            result.append(KlasseListItem(
                id: k.id!,
                name: k.name,
                studentCount: studentCount,
                hasActiveCode: hasActiveCode
            ))
        }
        return result
    }

    // GET /api/admin/klassen/:klasseID/detail
    @Sendable
    func getKlasseDetail(req: Request) async throws -> KlasseDetailResponse {
        guard let klasseID: UUID = req.parameters.get("klasseID") else {
            throw Abort(.badRequest)
        }
        guard let klasse = try await Klasse.find(klasseID, on: req.db) else {
            throw Abort(.notFound, reason: "Klasse nicht gefunden.")
        }

        let students = try await Player.query(on: req.db)
            .filter(\.$klasse == klasse.name)
            .sort(\.$name)
            .all()
            .map { StudentNameEntry(id: $0.id!, name: $0.name) }

        // Find active code
        let activeLC = try await LessonCode.query(on: req.db)
            .filter(\.$klasse.$id == klasseID)
            .filter(\.$active == true)
            .first()

        var activeCode: LessonCodeResponse? = nil
        if let lc = activeLC, lc.isValid {
            activeCode = LessonCodeResponse(
                id: lc.id!,
                code: lc.code,
                klasse: klasse.name,
                klasseID: klasseID,
                expiresAt: lc.expiresAt,
                joinURL: "/join.html?code=\(lc.code)"
            )
        }

        return KlasseDetailResponse(
            id: klasseID,
            name: klasse.name,
            studentCount: students.count,
            students: students,
            activeCode: activeCode
        )
    }

    // POST /api/admin/klassen/:klasseID/students
    @Sendable
    func addStudents(req: Request) async throws -> AddStudentsResponse {
        guard let klasseID: UUID = req.parameters.get("klasseID") else {
            throw Abort(.badRequest)
        }
        guard let klasse = try await Klasse.find(klasseID, on: req.db) else {
            throw Abort(.notFound, reason: "Klasse nicht gefunden.")
        }

        let input = try req.content.decode(AddStudentsRequest.self)
        var created = 0
        var existing = 0

        for rawName in input.names {
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            // Check if player already exists for this klasse
            if let _ = try await Player.query(on: req.db)
                .filter(\.$name == name)
                .filter(\.$klasse == klasse.name)
                .first() {
                existing += 1
            } else {
                let player = Player(name: name, klasse: klasse.name)
                try await player.save(on: req.db)
                created += 1
            }
        }

        return AddStudentsResponse(created: created, existing: existing)
    }

    // DELETE /api/admin/klassen/:klasseID
    @Sendable
    func deleteKlasse(req: Request) async throws -> HTTPStatus {
        guard let klasseID: UUID = req.parameters.get("klasseID") else {
            throw Abort(.badRequest)
        }
        guard let klasse = try await Klasse.find(klasseID, on: req.db) else {
            throw Abort(.notFound)
        }

        // Deactivate lesson codes
        try await LessonCode.query(on: req.db)
            .filter(\.$klasse.$id == klasseID)
            .delete()

        try await klasse.delete(on: req.db)
        return .ok
    }

    // DELETE /api/admin/klassen/:klasseID/students/:playerID
    @Sendable
    func removeStudent(req: Request) async throws -> HTTPStatus {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }
        // Delete related data
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

    // MARK: - Lesson Codes

    // POST /api/admin/klassen/:klasseID/start-lesson
    @Sendable
    func startLesson(req: Request) async throws -> LessonCodeResponse {
        guard let klasseID: UUID = req.parameters.get("klasseID") else {
            throw Abort(.badRequest)
        }
        guard let klasse = try await Klasse.find(klasseID, on: req.db) else {
            throw Abort(.notFound, reason: "Klasse nicht gefunden.")
        }

        let input = try? req.content.decode(StartLessonRequest.self)
        let duration = input?.durationMinutes ?? 90

        // Deactivate any existing active codes for this class
        let activeCodes = try await LessonCode.query(on: req.db)
            .filter(\.$klasse.$id == klasseID)
            .filter(\.$active == true)
            .all()
        for code in activeCodes {
            code.active = false
            try await code.save(on: req.db)
        }

        // Generate unique code
        var code = generateCode()
        while try await LessonCode.query(on: req.db)
            .filter(\.$code == code)
            .filter(\.$active == true)
            .first() != nil {
            code = generateCode()
        }

        let lessonCode = LessonCode(klasseID: klasseID, code: code, durationMinutes: duration)
        try await lessonCode.save(on: req.db)

        return LessonCodeResponse(
            id: lessonCode.id!,
            code: code,
            klasse: klasse.name,
            klasseID: klasseID,
            expiresAt: lessonCode.expiresAt,
            joinURL: "/join.html?code=\(code)"
        )
    }

    // POST /api/admin/klassen/:klasseID/stop-lesson
    @Sendable
    func stopLesson(req: Request) async throws -> HTTPStatus {
        guard let klasseID: UUID = req.parameters.get("klasseID") else {
            throw Abort(.badRequest)
        }

        let activeCodes = try await LessonCode.query(on: req.db)
            .filter(\.$klasse.$id == klasseID)
            .filter(\.$active == true)
            .all()
        for code in activeCodes {
            code.active = false
            try await code.save(on: req.db)
        }
        return .ok
    }

    // MARK: - Public Join

    // GET /api/join/:code
    @Sendable
    func getJoinInfo(req: Request) async throws -> JoinCodeInfoResponse {
        guard let codeStr: String = req.parameters.get("code") else {
            throw Abort(.badRequest)
        }

        guard let lessonCode = try await LessonCode.query(on: req.db)
            .filter(\.$code == codeStr.uppercased())
            .with(\.$klasse)
            .first(),
            lessonCode.isValid else {
            throw Abort(.gone, reason: "Dieser Code ist abgelaufen oder ungültig. Bitte scanne einen neuen QR-Code.")
        }

        let students = try await Player.query(on: req.db)
            .filter(\.$klasse == lessonCode.klasse.name)
            .sort(\.$name)
            .all()
            .map { StudentNameEntry(id: $0.id!, name: $0.name) }

        return JoinCodeInfoResponse(
            klasse: lessonCode.klasse.name,
            students: students
        )
    }

    // POST /api/join/:code/checkin
    @Sendable
    func checkinWithCode(req: Request) async throws -> CodeCheckinResponse {
        guard let codeStr: String = req.parameters.get("code") else {
            throw Abort(.badRequest)
        }

        guard let lessonCode = try await LessonCode.query(on: req.db)
            .filter(\.$code == codeStr.uppercased())
            .with(\.$klasse)
            .first(),
            lessonCode.isValid else {
            throw Abort(.gone, reason: "Dieser Code ist abgelaufen oder ungültig.")
        }

        let input = try req.content.decode(CodeCheckinRequest.self)

        guard let player = try await Player.find(input.playerID, on: req.db) else {
            throw Abort(.notFound, reason: "Schüler nicht gefunden.")
        }

        // Verify student belongs to this class
        guard player.klasse == lessonCode.klasse.name else {
            throw Abort(.forbidden, reason: "Schüler gehört nicht zu dieser Klasse.")
        }

        // Update last seen
        player.lastSeen = Date()
        try await player.save(on: req.db)

        // Check out from any existing checkins
        let existingCheckins = try await LernraumCheckin.query(on: req.db)
            .filter(\.$player.$id == player.id!)
            .filter(\.$checkedOutAt == nil)
            .all()
        for checkin in existingCheckins {
            checkin.checkedOutAt = Date()
            try await checkin.save(on: req.db)
        }

        // Create new checkin with class name as raum
        let checkin = LernraumCheckin(playerID: player.id!, raum: lessonCode.klasse.name)
        try await checkin.save(on: req.db)

        return CodeCheckinResponse(
            id: player.id!,
            name: player.name,
            klasse: player.klasse,
            message: "Willkommen, \(player.name)!"
        )
    }

    // MARK: - Helpers

    private func generateCode(length: Int = 4) -> String {
        let chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
