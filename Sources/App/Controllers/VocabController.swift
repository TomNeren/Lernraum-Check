import Vapor
import Fluent

struct VocabController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let vocab = routes.grouped("api", "vocab")

        vocab.post("import", use: importVocab)
        vocab.get("due", ":playerID", use: getDueCards)
        vocab.post("review", use: reviewCard)
        vocab.get("stats", ":playerID", use: getStats)
        vocab.get("topics", use: getTopics)

        // Admin vocab management
        let adminVocab = routes.grouped("api", "admin", "vocab")
        adminVocab.get("topics", use: adminGetTopics)
        adminVocab.get("topic", ":topicName", use: adminGetTopicItems)
        adminVocab.put("items", ":vocabID", use: adminUpdateItem)
        adminVocab.delete("items", ":vocabID", use: adminDeleteItem)
        adminVocab.delete("topic", ":topicName", use: adminDeleteTopic)

        // Assignments
        let assign = routes.grouped("api", "admin", "assign")
        assign.post(use: assignContent)
        assign.delete(":assignmentID", use: removeAssignment)
        assign.get("game", ":gameID", use: getGameAssignments)
        assign.get("vocab-topic", ":topicName", use: getVocabTopicAssignments)
    }

    // POST /api/vocab/import
    @Sendable
    func importVocab(req: Request) async throws -> HTTPStatus {
        let input = try req.content.decode(VocabImportRequest.self)

        for item in input.items {
            // Duplikate ignorieren
            let existing = try await VocabItem.query(on: req.db)
                .filter(\.$english == item.english)
                .filter(\.$german == item.german)
                .first()

            if existing == nil {
                let vocab = VocabItem(
                    english: item.english,
                    german: item.german,
                    example: item.example,
                    topic: input.topic,
                    difficulty: 1
                )
                try await vocab.save(on: req.db)
            }
        }

        return .ok
    }

    // GET /api/vocab/due/:playerID
    @Sendable
    func getDueCards(req: Request) async throws -> [VocabDueCard] {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        let now = Date()

        // Check if topic assignments exist
        let player = try await Player.find(playerID, on: req.db)
        let allTopicAssignments = try await ContentAssignment.query(on: req.db)
            .filter(\.$contentType == "vocab-topic")
            .count()

        let allVocab: [VocabItem]
        if allTopicAssignments == 0 {
            // No assignments — show all (backwards compatible)
            allVocab = try await VocabItem.query(on: req.db).all()
        } else {
            // Get assigned topics for player's class + individual
            var topicQuery = ContentAssignment.query(on: req.db)
                .filter(\.$contentType == "vocab-topic")
            if let player = player {
                topicQuery = topicQuery.group(.or) { or in
                    or.filter(\.$klasse == player.klasse)
                    or.filter(\.$playerID == playerID)
                }
            }
            let assignments = try await topicQuery.all()
            let assignedTopics = assignments.map { $0.contentValue }

            if assignedTopics.isEmpty {
                return []
            }
            allVocab = try await VocabItem.query(on: req.db)
                .filter(\.$topic ~~ assignedTopics)
                .all()
        }

        // Bestehende Progress-Einträge für diesen Player
        let existingProgress = try await VocabProgress.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .all()

        let progressByVocabID = Dictionary(uniqueKeysWithValues: existingProgress.map { p in
            (p.$vocab.id, p)
        })

        var dueCards: [VocabDueCard] = []

        for vocab in allVocab {
            guard let vocabID = vocab.id else { continue }

            if let progress = progressByVocabID[vocabID] {
                // Nur fällige Karten
                if progress.nextReview <= now {
                    dueCards.append(VocabDueCard(
                        vocabID: vocabID,
                        english: vocab.english,
                        german: vocab.german,
                        exampleSentence: vocab.exampleSentence,
                        box: progress.box,
                        topic: vocab.topic
                    ))
                }
            } else {
                // Neue Karte — Progress erstellen
                let progress = VocabProgress(playerID: playerID, vocabID: vocabID)
                try await progress.save(on: req.db)

                dueCards.append(VocabDueCard(
                    vocabID: vocabID,
                    english: vocab.english,
                    german: vocab.german,
                    exampleSentence: vocab.exampleSentence,
                    box: 1,
                    topic: vocab.topic
                ))
            }

            if dueCards.count >= 20 { break }
        }

        return dueCards
    }

    // POST /api/vocab/review
    @Sendable
    func reviewCard(req: Request) async throws -> VocabProgress {
        let input = try req.content.decode(VocabReviewRequest.self)

        guard let progress = try await VocabProgress.query(on: req.db)
            .filter(\.$player.$id == input.playerID)
            .filter(\.$vocab.$id == input.vocabID)
            .first() else {
            throw Abort(.notFound, reason: "Kein Progress-Eintrag gefunden.")
        }

        let quality = max(0, min(3, input.quality))

        switch quality {
        case 0: // Nochmal
            progress.repetitions = 0
            progress.intervalDays = 0
            progress.box = max(1, progress.box - 1)
            progress.correctStreak = 0
        case 1: // Schwer
            progress.repetitions += 1
            progress.intervalDays = 1
            progress.correctStreak = 0
        case 2: // Gut
            progress.repetitions += 1
            let intervals = [1, 3, 7, 14, 30]
            let index = min(progress.repetitions - 1, 4)
            progress.intervalDays = intervals[max(0, index)]
            progress.box = min(5, progress.box + 1)
            progress.correctStreak += 1
        case 3: // Leicht
            progress.repetitions += 1
            progress.intervalDays = max(1, Int(Double(max(1, progress.intervalDays)) * progress.easeFactor))
            progress.box = min(5, progress.box + 1)
            progress.correctStreak += 1
        default:
            break
        }

        // Ease Factor anpassen (SM-2)
        progress.easeFactor = max(1.3, progress.easeFactor + (0.1 - Double(3 - quality) * 0.08))

        // Nächster Review-Termin
        progress.nextReview = Calendar.current.date(byAdding: .day, value: progress.intervalDays, to: Date()) ?? Date()

        try await progress.save(on: req.db)
        return progress
    }

    // GET /api/vocab/stats/:playerID
    @Sendable
    func getStats(req: Request) async throws -> VocabStats {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        let now = Date()
        let allProgress = try await VocabProgress.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .all()

        var box1 = 0, box2 = 0, box3 = 0, box4 = 0, box5 = 0
        var dueToday = 0

        for p in allProgress {
            switch p.box {
            case 1: box1 += 1
            case 2: box2 += 1
            case 3: box3 += 1
            case 4: box4 += 1
            case 5: box5 += 1
            default: box1 += 1
            }
            if p.nextReview <= now {
                dueToday += 1
            }
        }

        return VocabStats(
            box1: box1, box2: box2, box3: box3, box4: box4, box5: box5,
            total: allProgress.count,
            dueToday: dueToday
        )
    }

    // GET /api/vocab/topics
    @Sendable
    func getTopics(req: Request) async throws -> [String] {
        let items = try await VocabItem.query(on: req.db)
            .filter(\.$topic != nil)
            .all()

        let topics = Set(items.compactMap { $0.topic })
        return Array(topics).sorted()
    }

    // MARK: - Admin Vocab Management

    // GET /api/admin/vocab/topics — Topics with item counts and assignments
    @Sendable
    func adminGetTopics(req: Request) async throws -> [TopicDetail] {
        let items = try await VocabItem.query(on: req.db).all()
        let assignments = try await ContentAssignment.query(on: req.db)
            .filter(\.$contentType == "vocab-topic")
            .all()

        // Group items by topic
        var topicCounts: [String: Int] = [:]
        for item in items {
            let topic = item.topic ?? "(Kein Thema)"
            topicCounts[topic, default: 0] += 1
        }

        // Group assignments by topic
        var topicAssignments: [String: [String]] = [:]
        for a in assignments {
            let klasse = a.klasse ?? "Einzelzuweisung"
            topicAssignments[a.contentValue, default: []].append(klasse)
        }

        return topicCounts.map { (topic, count) in
            TopicDetail(
                topic: topic,
                itemCount: count,
                assignedTo: topicAssignments[topic] ?? []
            )
        }.sorted { $0.topic < $1.topic }
    }

    // GET /api/admin/vocab/topic/:topicName — Items in a topic
    @Sendable
    func adminGetTopicItems(req: Request) async throws -> [VocabItemResponse] {
        guard let topicName: String = req.parameters.get("topicName") else {
            throw Abort(.badRequest)
        }

        let decodedTopic = topicName.removingPercentEncoding ?? topicName

        let items: [VocabItem]
        if decodedTopic == "(Kein Thema)" {
            items = try await VocabItem.query(on: req.db)
                .filter(\.$topic == nil)
                .sort(\.$english)
                .all()
        } else {
            items = try await VocabItem.query(on: req.db)
                .filter(\.$topic == decodedTopic)
                .sort(\.$english)
                .all()
        }

        return items.map { item in
            VocabItemResponse(
                id: item.id!,
                english: item.english,
                german: item.german,
                exampleSentence: item.exampleSentence,
                topic: item.topic,
                difficulty: item.difficulty
            )
        }
    }

    // PUT /api/admin/vocab/items/:vocabID — Update a vocab item
    @Sendable
    func adminUpdateItem(req: Request) async throws -> VocabItemResponse {
        guard let vocabID: UUID = req.parameters.get("vocabID") else {
            throw Abort(.badRequest)
        }
        guard let item = try await VocabItem.find(vocabID, on: req.db) else {
            throw Abort(.notFound, reason: "Vokabel nicht gefunden.")
        }

        let input = try req.content.decode(VocabItemUpdateRequest.self)
        if let english = input.english { item.english = english }
        if let german = input.german { item.german = german }
        if let example = input.exampleSentence { item.exampleSentence = example }
        if let topic = input.topic { item.topic = topic }
        if let difficulty = input.difficulty { item.difficulty = difficulty }

        try await item.save(on: req.db)

        return VocabItemResponse(
            id: item.id!,
            english: item.english,
            german: item.german,
            exampleSentence: item.exampleSentence,
            topic: item.topic,
            difficulty: item.difficulty
        )
    }

    // DELETE /api/admin/vocab/items/:vocabID — Delete a vocab item + progress
    @Sendable
    func adminDeleteItem(req: Request) async throws -> HTTPStatus {
        guard let vocabID: UUID = req.parameters.get("vocabID") else {
            throw Abort(.badRequest)
        }
        // Delete progress entries first
        try await VocabProgress.query(on: req.db)
            .filter(\.$vocab.$id == vocabID)
            .delete()

        guard let item = try await VocabItem.find(vocabID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await item.delete(on: req.db)
        return .ok
    }

    // DELETE /api/admin/vocab/topic/:topicName — Delete entire topic
    @Sendable
    func adminDeleteTopic(req: Request) async throws -> HTTPStatus {
        guard let topicName: String = req.parameters.get("topicName") else {
            throw Abort(.badRequest)
        }
        let decodedTopic = topicName.removingPercentEncoding ?? topicName

        let items: [VocabItem]
        if decodedTopic == "(Kein Thema)" {
            items = try await VocabItem.query(on: req.db).filter(\.$topic == nil).all()
        } else {
            items = try await VocabItem.query(on: req.db).filter(\.$topic == decodedTopic).all()
        }

        for item in items {
            try await VocabProgress.query(on: req.db).filter(\.$vocab.$id == item.id!).delete()
            try await item.delete(on: req.db)
        }

        // Remove assignments
        try await ContentAssignment.query(on: req.db)
            .filter(\.$contentType == "vocab-topic")
            .filter(\.$contentValue == decodedTopic)
            .delete()

        return .ok
    }

    // MARK: - Content Assignments

    // POST /api/admin/assign — Assign content to class or player
    @Sendable
    func assignContent(req: Request) async throws -> ContentAssignment {
        let input = try req.content.decode(AssignContentRequest.self)

        guard input.contentType == "vocab-topic" || input.contentType == "game" else {
            throw Abort(.badRequest, reason: "contentType muss 'vocab-topic' oder 'game' sein.")
        }
        guard input.klasse != nil || input.playerID != nil else {
            throw Abort(.badRequest, reason: "klasse oder playerID muss angegeben werden.")
        }

        // Check for duplicate
        var query = ContentAssignment.query(on: req.db)
            .filter(\.$contentType == input.contentType)
            .filter(\.$contentValue == input.contentValue)
        if let klasse = input.klasse {
            query = query.filter(\.$klasse == klasse)
        }
        if let playerID = input.playerID {
            query = query.filter(\.$playerID == playerID)
        }
        if let _ = try await query.first() {
            throw Abort(.conflict, reason: "Diese Zuweisung existiert bereits.")
        }

        let assignment = ContentAssignment(
            contentType: input.contentType,
            contentValue: input.contentValue,
            klasse: input.klasse,
            playerID: input.playerID
        )
        try await assignment.save(on: req.db)
        return assignment
    }

    // DELETE /api/admin/assign/:assignmentID
    @Sendable
    func removeAssignment(req: Request) async throws -> HTTPStatus {
        guard let assignmentID: UUID = req.parameters.get("assignmentID") else {
            throw Abort(.badRequest)
        }
        guard let assignment = try await ContentAssignment.find(assignmentID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await assignment.delete(on: req.db)
        return .ok
    }

    // GET /api/admin/assign/game/:gameID — Get assignments for a game
    @Sendable
    func getGameAssignments(req: Request) async throws -> [ContentAssignment] {
        guard let gameID: String = req.parameters.get("gameID") else {
            throw Abort(.badRequest)
        }
        return try await ContentAssignment.query(on: req.db)
            .filter(\.$contentType == "game")
            .filter(\.$contentValue == gameID)
            .all()
    }

    // GET /api/admin/assign/vocab-topic/:topicName — Get assignments for a topic
    @Sendable
    func getVocabTopicAssignments(req: Request) async throws -> [ContentAssignment] {
        guard let topicName: String = req.parameters.get("topicName") else {
            throw Abort(.badRequest)
        }
        let decoded = topicName.removingPercentEncoding ?? topicName
        return try await ContentAssignment.query(on: req.db)
            .filter(\.$contentType == "vocab-topic")
            .filter(\.$contentValue == decoded)
            .all()
    }
}
