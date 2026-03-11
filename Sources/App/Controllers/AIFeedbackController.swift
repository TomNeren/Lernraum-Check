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
        Du bist ein freundlicher Lernassistent für Schüler (Klasse \(player.klasse)).
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

        Bitte gib dem Schüler:
        1. Kurzes, ermutigendes Feedback (2-3 Sätze)
        2. Einen konkreten Lerntipp basierend auf den Fehlern
        3. Eine Empfehlung, was als nächstes geübt werden sollte

        Antworte auf Deutsch, freundlich und motivierend. Maximal 150 Wörter.
        """

        // Call AI
        let aiResponse = try await callAI(prompt: prompt, req: req)

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
        try await feedback.save(on: req.db)

        return AIFeedbackResponse(
            id: feedback.id!,
            feedbackType: "game_review",
            text: aiResponse.text,
            tips: extractTips(from: aiResponse.text),
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

        Bitte gib dem Schüler:
        1. Ermutigendes Feedback (1-2 Sätze)
        2. Konkrete Merkhilfen/Eselsbrücken für die schwierigen Wörter
        3. Einen Lerntipp für Vokabeln

        Antworte auf Deutsch, freundlich und motivierend. Maximal 200 Wörter.
        """

        let aiResponse = try await callAI(prompt: prompt, req: req)

        let feedback = AIFeedback(
            playerID: player.id!,
            feedbackType: "vocab_tip",
            promptUsed: prompt,
            aiResponse: aiResponse.text,
            modelUsed: aiResponse.model
        )
        try await feedback.save(on: req.db)

        return AIFeedbackResponse(
            id: feedback.id!,
            feedbackType: "vocab_tip",
            text: aiResponse.text,
            tips: extractTips(from: aiResponse.text),
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
            tips: [],
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
            AIFeedbackResponse(
                id: fb.id!,
                feedbackType: fb.feedbackType,
                text: fb.aiResponse,
                tips: extractTips(from: fb.aiResponse),
                createdAt: fb.createdAt ?? Date()
            )
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
            AIFeedbackResponse(
                id: fb.id!,
                feedbackType: fb.feedbackType,
                text: fb.aiResponse,
                tips: extractTips(from: fb.aiResponse),
                createdAt: fb.createdAt ?? Date()
            )
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

        return AIFeedbackResponse(
            id: fb.id!,
            feedbackType: fb.feedbackType,
            text: fb.aiResponse,
            tips: extractTips(from: fb.aiResponse),
            createdAt: fb.createdAt ?? Date()
        )
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

    // MARK: - AI Call Helper

    private func callAI(prompt: String, req: Request) async throws -> AICallResult {
        let apiKey = Environment.get("CLAUDE_API_KEY") ?? ""
        guard !apiKey.isEmpty else {
            // Fallback: generate basic feedback without AI
            return AICallResult(
                text: generateFallbackFeedback(prompt: prompt),
                model: "fallback-local"
            )
        }

        let model = Environment.get("CLAUDE_MODEL") ?? "claude-haiku-4-5-20251001"
        let maxTokens = Int(Environment.get("CLAUDE_MAX_TOKENS") ?? "500") ?? 500

        // Call Claude API via HTTP
        let apiURL = URI(string: "https://api.anthropic.com/v1/messages")

        struct ClaudeRequest: Content {
            let model: String
            let max_tokens: Int
            let messages: [ClaudeMessage]
        }

        struct ClaudeMessage: Content {
            let role: String
            let content: String
        }

        struct ClaudeResponse: Content {
            let content: [ClaudeContentBlock]
        }

        struct ClaudeContentBlock: Content {
            let type: String
            let text: String?
        }

        let body = ClaudeRequest(
            model: model,
            max_tokens: maxTokens,
            messages: [ClaudeMessage(role: "user", content: prompt)]
        )

        var headers = HTTPHeaders()
        headers.add(name: "x-api-key", value: apiKey)
        headers.add(name: "anthropic-version", value: "2023-06-01")
        headers.add(name: "content-type", value: "application/json")

        let response = try await req.client.post(apiURL, headers: headers) { clientReq in
            try clientReq.content.encode(body)
        }

        guard response.status == .ok else {
            let errorBody = response.body.map { String(buffer: $0) } ?? "Unknown error"
            req.logger.error("Claude API error: \(response.status) - \(errorBody)")
            // Fallback on API error
            return AICallResult(
                text: generateFallbackFeedback(prompt: prompt),
                model: "fallback-api-error"
            )
        }

        let claudeResponse = try response.content.decode(ClaudeResponse.self)
        let text = claudeResponse.content.compactMap(\.text).joined(separator: "\n")

        return AICallResult(text: text, model: model)
    }

    // MARK: - Fallback (ohne API-Key)

    private func generateFallbackFeedback(prompt: String) -> String {
        // Simple rule-based feedback when no API key is configured
        if prompt.contains("Vokabel") {
            return """
            Gut gemacht beim Vokabellernen! 📚

            Tipp: Versuche, die schwierigen Wörter in eigenen Sätzen zu verwenden. \
            Das hilft dir, sie besser zu behalten. Wiederhole die Wörter, die dir schwer \
            fallen, am besten morgen noch einmal.

            Weiter so! 💪
            """
        }

        if prompt.contains("Punkte") || prompt.contains("Spiel") {
            return """
            Toll, dass du geübt hast! 🎮

            Tipp: Schau dir die Fragen, die du falsch hattest, noch einmal genauer an. \
            Oft hilft es, die richtige Antwort laut auszusprechen. Probiere das Spiel \
            gleich noch einmal — du wirst sehen, dass du dich verbesserst!

            Du schaffst das! 🌟
            """
        }

        return """
        Danke für deine Frage! 🤗

        Versuche, das Thema in kleinen Schritten zu üben. Wenn du unsicher bist, \
        frag deine Lehrkraft oder nutze die Übungen hier auf der Plattform.

        Viel Erfolg beim Lernen! ✨
        """
    }

    // MARK: - Helpers

    private func extractTips(from text: String) -> [String] {
        // Extract numbered tips from AI response
        var tips: [String] = []
        let lines = text.split(separator: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match lines starting with numbers (1., 2., 3., etc.) or bullet points
            if trimmed.first?.isNumber == true && trimmed.contains(".") {
                let tip = trimmed.drop(while: { $0.isNumber || $0 == "." || $0 == " " })
                if !tip.isEmpty { tips.append(String(tip)) }
            } else if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") {
                let tip = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                if !tip.isEmpty { tips.append(tip) }
            }
        }
        return tips
    }
}

// Internal helper
struct AICallResult {
    let text: String
    let model: String
}
