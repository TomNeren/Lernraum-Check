import Vapor
import Fluent

struct AIFeedbackController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let ai = routes.grouped("api", "ai")

        // Generate feedback
        ai.post("feedback", "game", use: generateGameFeedback)
        ai.post("feedback", "vocab", use: generateVocabFeedback)
        ai.post("feedback", "general", use: generateGeneralFeedback)

        // Retrieve feedback
        ai.get("feedback", "player", ":playerID", use: getPlayerFeedback)
        ai.get("feedback", "session", ":sessionID", use: getSessionFeedback)
        ai.get("feedback", ":feedbackID", use: getFeedback)

        // Admin
        ai.get("feedback", "all", use: getAllFeedback)
        ai.get("feedback", "stats", use: getFeedbackStats)

        // Config
        ai.get("config", use: getAIConfig)
        ai.post("config", use: updateAIConfig)
    }

    // MARK: - Game Feedback

    // POST /api/ai/feedback/game
    @Sendable
    func generateGameFeedback(req: Request) async throws -> AIFeedbackResponse {
        let input = try req.content.decode(GameFeedbackRequest.self)

        // Load player
        guard let player = try await Player.find(input.playerID, on: req.db) else {
            throw Abort(.notFound, reason: "Spieler nicht gefunden.")
        }

        // Load session with details
        guard let session = try await GameSession.query(on: req.db)
            .filter(\.$id == input.sessionID)
            .with(\.$module)
            .first() else {
            throw Abort(.notFound, reason: "Spielsitzung nicht gefunden.")
        }

        // Build prompt for AI
        let percentage = session.maxScore > 0 ? Int(Double(session.score) / Double(session.maxScore) * 100) : 0
        let wrongAnswers = session.details?.answers.filter { !$0.correct } ?? []

        var prompt = """
        Du bist ein freundlicher Englisch-Lernassistent für Schüler (Klasse \(player.klasse)).
        Der Schüler \(player.name) hat gerade das Spiel "\(session.module.title)" gespielt.

        Ergebnis: \(session.score)/\(session.maxScore) Punkte (\(percentage)%)
        Dauer: \(session.timeSpent) Sekunden
        Spieltyp: \(session.module.type)
        """

        if !wrongAnswers.isEmpty {
            prompt += "\n\nFalsche Antworten:\n"
            for answer in wrongAnswers {
                prompt += "- Antwort: \"\(answer.givenAnswer)\" (falsch)\n"
            }
        }

        prompt += """

        Gib dein Feedback ausschließlich in folgender Struktur:

        --- INHALT ---
        Was hat der Schüler inhaltlich gut gemacht? Wo gab es Lücken? (2-3 Sätze)

        --- SPRACHE ---
        Welche sprachlichen Fehler sind aufgefallen? Grammatik, Wortschatz, Rechtschreibung? (2-3 Sätze, mit konkreten Beispielen aus den falschen Antworten)

        --- NÄCHSTER SCHRITT ---
        Ein konkreter, machbarer Tipp. Was genau sollte als nächstes geübt werden? Schlage wenn möglich eine Übungsart vor (Vokabeltraining, Grammatikübung, Leseübung).

        Antworte auf Deutsch, freundlich und motivierend. Maximal 200 Wörter insgesamt.
        """

        // Call AI
        let aiResponse = try await callAI(prompt: prompt, req: req)

        // Parse structured sections
        let inhalt = extractSection(from: aiResponse.text, marker: "--- INHALT ---", endMarker: "--- SPRACHE ---")
        let sprache = extractSection(from: aiResponse.text, marker: "--- SPRACHE ---", endMarker: "--- NÄCHSTER SCHRITT ---")
        let naechsterSchritt = extractSection(from: aiResponse.text, marker: "--- NÄCHSTER SCHRITT ---", endMarker: nil)

        // Save feedback
        let feedback = AIFeedback(
            playerID: player.id!,
            sessionID: session.id,
            feedbackType: "game_review",
            promptUsed: prompt,
            aiResponse: aiResponse.text,
            scoreBefore: session.score,
            modelUsed: aiResponse.model
        )
        feedback.feedbackInhalt = inhalt
        feedback.feedbackSprache = sprache
        feedback.feedbackNaechsterSchritt = naechsterSchritt
        try await feedback.save(on: req.db)

        return AIFeedbackResponse(
            id: feedback.id!,
            feedbackType: "game_review",
            text: aiResponse.text,
            inhalt: inhalt,
            sprache: sprache,
            naechsterSchritt: naechsterSchritt,
            createdAt: feedback.createdAt ?? Date()
        )
    }

    // MARK: - Vocab Feedback

    // POST /api/ai/feedback/vocab
    @Sendable
    func generateVocabFeedback(req: Request) async throws -> AIFeedbackResponse {
        let input = try req.content.decode(VocabFeedbackRequest.self)

        guard let player = try await Player.find(input.playerID, on: req.db) else {
            throw Abort(.notFound, reason: "Spieler nicht gefunden.")
        }

        // Build prompt
        var prompt = """
        Du bist ein freundlicher Englisch-Lernassistent für Schüler (Klasse \(player.klasse)).
        Der Schüler \(player.name) übt Vokabeln.

        """

        if !input.difficultWords.isEmpty {
            prompt += "Schwierige Wörter (oft falsch):\n"
            for word in input.difficultWords {
                prompt += "- \(word.english) = \(word.german)"
                if let example = word.example {
                    prompt += " (Beispiel: \(example))"
                }
                prompt += "\n"
            }
        }

        prompt += """

        Statistik: \(input.totalReviewed) Karten geübt, \(input.correctCount) richtig.

        Gib dein Feedback ausschließlich in folgender Struktur:

        --- INHALT ---
        Kurze Einordnung des Ergebnisses. Was lief gut, wo gibt es Lücken? (1-2 Sätze)

        --- SPRACHE ---
        Konkrete Merkhilfen und Eselsbrücken für die schwierigen Wörter. Nenne die Wörter und gib jeweils eine Merkhilfe. (so viele wie nötig)

        --- NÄCHSTER SCHRITT ---
        Ein konkreter Tipp für die nächste Vokabel-Übung. Was sollte wiederholt werden?

        Antworte auf Deutsch, freundlich und motivierend. Maximal 200 Wörter insgesamt.
        """

        let aiResponse = try await callAI(prompt: prompt, req: req)

        // Parse structured sections
        let inhalt = extractSection(from: aiResponse.text, marker: "--- INHALT ---", endMarker: "--- SPRACHE ---")
        let sprache = extractSection(from: aiResponse.text, marker: "--- SPRACHE ---", endMarker: "--- NÄCHSTER SCHRITT ---")
        let naechsterSchritt = extractSection(from: aiResponse.text, marker: "--- NÄCHSTER SCHRITT ---", endMarker: nil)

        let feedback = AIFeedback(
            playerID: player.id!,
            feedbackType: "vocab_tip",
            promptUsed: prompt,
            aiResponse: aiResponse.text,
            modelUsed: aiResponse.model
        )
        feedback.feedbackInhalt = inhalt
        feedback.feedbackSprache = sprache
        feedback.feedbackNaechsterSchritt = naechsterSchritt
        try await feedback.save(on: req.db)

        return AIFeedbackResponse(
            id: feedback.id!,
            feedbackType: "vocab_tip",
            text: aiResponse.text,
            inhalt: inhalt,
            sprache: sprache,
            naechsterSchritt: naechsterSchritt,
            createdAt: feedback.createdAt ?? Date()
        )
    }

    // MARK: - General Feedback

    // POST /api/ai/feedback/general
    @Sendable
    func generateGeneralFeedback(req: Request) async throws -> AIFeedbackResponse {
        let input = try req.content.decode(GeneralFeedbackRequest.self)

        guard let player = try await Player.find(input.playerID, on: req.db) else {
            throw Abort(.notFound, reason: "Spieler nicht gefunden.")
        }

        let prompt = """
        Du bist ein freundlicher Lernassistent für Schüler (Klasse \(player.klasse)).
        Der Schüler \(player.name) hat folgende Frage:

        "\(input.question)"

        Kontext: \(input.context ?? "Allgemeine Lernhilfe")

        Antworte auf Deutsch, freundlich und hilfreich. Maximal 150 Wörter.
        Wenn die Frage nichts mit Lernen zu tun hat, lenke freundlich zurück zum Thema.
        """

        let aiResponse = try await callAI(prompt: prompt, req: req)

        let feedback = AIFeedback(
            playerID: player.id!,
            feedbackType: "general",
            promptUsed: prompt,
            aiResponse: aiResponse.text,
            modelUsed: aiResponse.model
        )
        try await feedback.save(on: req.db)

        return AIFeedbackResponse(
            id: feedback.id!,
            feedbackType: "general",
            text: aiResponse.text,
            inhalt: nil,
            sprache: nil,
            naechsterSchritt: nil,
            createdAt: feedback.createdAt ?? Date()
        )
    }

    // MARK: - Retrieve Feedback

    // GET /api/ai/feedback/player/:playerID
    @Sendable
    func getPlayerFeedback(req: Request) async throws -> [AIFeedbackResponse] {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        let feedbacks = try await AIFeedback.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .sort(\.$createdAt, .descending)
            .range(..<20)
            .all()

        return feedbacks.map { fb in
            mapFeedbackResponse(fb)
        }
    }

    // GET /api/ai/feedback/session/:sessionID
    @Sendable
    func getSessionFeedback(req: Request) async throws -> [AIFeedbackResponse] {
        guard let sessionID: UUID = req.parameters.get("sessionID") else {
            throw Abort(.badRequest)
        }

        let feedbacks = try await AIFeedback.query(on: req.db)
            .filter(\.$session.$id == sessionID)
            .sort(\.$createdAt, .descending)
            .all()

        return feedbacks.map { fb in
            mapFeedbackResponse(fb)
        }
    }

    // GET /api/ai/feedback/:feedbackID
    @Sendable
    func getFeedback(req: Request) async throws -> AIFeedbackResponse {
        guard let feedbackID: UUID = req.parameters.get("feedbackID") else {
            throw Abort(.badRequest)
        }

        guard let fb = try await AIFeedback.find(feedbackID, on: req.db) else {
            throw Abort(.notFound, reason: "Feedback nicht gefunden.")
        }

        return mapFeedbackResponse(fb)
    }

    // GET /api/ai/feedback/all
    @Sendable
    func getAllFeedback(req: Request) async throws -> [AIFeedbackListItem] {
        let feedbacks = try await AIFeedback.query(on: req.db)
            .with(\.$player)
            .sort(\.$createdAt, .descending)
            .range(..<100)
            .all()

        return feedbacks.map { fb in
            AIFeedbackListItem(
                id: fb.id!,
                playerName: fb.player.name,
                klasse: fb.player.klasse,
                feedbackType: fb.feedbackType,
                preview: String(fb.aiResponse.prefix(100)),
                modelUsed: fb.modelUsed,
                createdAt: fb.createdAt ?? Date()
            )
        }
    }

    // GET /api/ai/feedback/stats
    @Sendable
    func getFeedbackStats(req: Request) async throws -> AIFeedbackStats {
        let all = try await AIFeedback.query(on: req.db).all()

        var byType: [String: Int] = [:]
        for fb in all {
            byType[fb.feedbackType, default: 0] += 1
        }

        return AIFeedbackStats(
            totalFeedbacks: all.count,
            byType: byType
        )
    }

    // MARK: - AI Config

    // GET /api/ai/config
    @Sendable
    func getAIConfig(req: Request) async throws -> AIConfigResponse {
        let apiKey = Environment.get("CLAUDE_API_KEY") ?? ""
        return AIConfigResponse(
            isConfigured: !apiKey.isEmpty,
            model: Environment.get("CLAUDE_MODEL") ?? "claude-haiku-4-5-20251001",
            maxTokens: Int(Environment.get("CLAUDE_MAX_TOKENS") ?? "500") ?? 500
        )
    }

    // POST /api/ai/config — test connection
    @Sendable
    func updateAIConfig(req: Request) async throws -> AIConfigTestResult {
        let apiKey = Environment.get("CLAUDE_API_KEY") ?? ""
        guard !apiKey.isEmpty else {
            return AIConfigTestResult(success: false, message: "CLAUDE_API_KEY nicht in .env gesetzt.")
        }

        do {
            let result = try await callAI(prompt: "Sage 'Verbindung OK' auf Deutsch.", req: req)
            return AIConfigTestResult(success: true, message: "Verbindung erfolgreich: \(result.text)")
        } catch {
            return AIConfigTestResult(success: false, message: "Fehler: \(error.localizedDescription)")
        }
    }

    // MARK: - AI Call Helper (delegates to shared ClaudeService)

    private func callAI(prompt: String, req: Request) async throws -> AICallResult {
        let result = try await ClaudeService.callAI(prompt: prompt, req: req)
        return AICallResult(text: result.text, model: result.model)
    }

    // MARK: - Helpers

    private func mapFeedbackResponse(_ fb: AIFeedback) -> AIFeedbackResponse {
        // Use stored structured fields if available, otherwise parse from raw text
        let inhalt = fb.feedbackInhalt ?? extractSection(from: fb.aiResponse, marker: "--- INHALT ---", endMarker: "--- SPRACHE ---")
        let sprache = fb.feedbackSprache ?? extractSection(from: fb.aiResponse, marker: "--- SPRACHE ---", endMarker: "--- NÄCHSTER SCHRITT ---")
        let naechsterSchritt = fb.feedbackNaechsterSchritt ?? extractSection(from: fb.aiResponse, marker: "--- NÄCHSTER SCHRITT ---", endMarker: nil)

        return AIFeedbackResponse(
            id: fb.id!,
            feedbackType: fb.feedbackType,
            text: fb.aiResponse,
            inhalt: inhalt.isEmpty ? nil : inhalt,
            sprache: sprache.isEmpty ? nil : sprache,
            naechsterSchritt: naechsterSchritt.isEmpty ? nil : naechsterSchritt,
            createdAt: fb.createdAt ?? Date()
        )
    }

    private func extractSection(from text: String, marker: String, endMarker: String?) -> String {
        guard let startRange = text.range(of: marker) else {
            return ""
        }
        let afterStart = text[startRange.upperBound...]
        if let end = endMarker, let endRange = afterStart.range(of: end) {
            return String(afterStart[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(afterStart).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Internal helper
struct AICallResult {
    let text: String
    let model: String
}
