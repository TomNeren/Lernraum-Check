import Vapor
import Fluent

struct VocabExerciseController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let vocab = routes.grouped("api", "vocab-exercise")

        vocab.post("generate", use: generateExercise)
        vocab.post("submit", use: submitExercise)
    }

    // MARK: - Generate Exercise

    // POST /api/vocab-exercise/generate
    @Sendable
    func generateExercise(req: Request) async throws -> VocabExerciseResponse {
        let input = try req.content.decode(GenerateExerciseRequest.self)

        // Check cache first (24h)
        let cutoff = Date().addingTimeInterval(-86400) // 24h ago

        if let cached = try await VocabExercise.query(on: req.db)
            .filter(\.$topic == input.topic)
            .filter(\.$exerciseType == input.exerciseType)
            .filter(\.$difficulty == input.difficulty)
            .filter(\.$createdAt > cutoff)
            .sort(\.$createdAt, .descending)
            .first() {
            return VocabExerciseResponse(
                id: cached.id!,
                exerciseType: cached.exerciseType,
                topic: cached.topic,
                difficulty: cached.difficulty,
                content: cached.contentJSON,
                modelUsed: cached.modelUsed,
                cached: true
            )
        }

        // Load vocab items for this topic
        let vocabItems = try await VocabItem.query(on: req.db)
            .filter(\.$topic == input.topic)
            .all()

        guard !vocabItems.isEmpty else {
            throw Abort(.badRequest, reason: "Keine Vokabeln für dieses Thema gefunden.")
        }

        // Build prompt based on exercise type
        let prompt = buildExercisePrompt(
            type: input.exerciseType,
            difficulty: input.difficulty,
            vocabItems: vocabItems
        )

        // Call AI
        let aiResult = try await ClaudeService.callAI(prompt: prompt, req: req, maxTokens: 1000)

        // Save to cache
        let exercise = VocabExercise(
            exerciseType: input.exerciseType,
            topic: input.topic,
            difficulty: input.difficulty,
            contentJSON: aiResult.text,
            modelUsed: aiResult.model,
            expiresAt: Date().addingTimeInterval(86400)
        )
        try await exercise.save(on: req.db)

        return VocabExerciseResponse(
            id: exercise.id!,
            exerciseType: exercise.exerciseType,
            topic: exercise.topic,
            difficulty: exercise.difficulty,
            content: exercise.contentJSON,
            modelUsed: exercise.modelUsed,
            cached: false
        )
    }

    // MARK: - Submit Exercise Answers

    // POST /api/vocab-exercise/submit
    @Sendable
    func submitExercise(req: Request) async throws -> ExerciseSubmitResponse {
        let input = try req.content.decode(ExerciseSubmitRequest.self)

        guard let player = try await Player.find(input.playerID, on: req.db) else {
            throw Abort(.notFound, reason: "Spieler nicht gefunden.")
        }

        // Build feedback prompt
        let prompt = """
        Du bist ein freundlicher Englisch-Lernassistent für Schüler (Klasse \(player.klasse)).
        Der Schüler \(player.name) hat eine Vokabelübung gemacht.

        Übungstyp: \(input.exerciseType)
        Thema: \(input.topic)
        Richtig: \(input.correctCount) von \(input.totalCount)

        Falsche Antworten:
        \(input.wrongAnswers.map { "- Erwartet: \"\($0.expected)\", Gegeben: \"\($0.given)\"" }.joined(separator: "\n"))

        Gib kurzes, ermutigendes Feedback (2-3 Sätze) und einen Lerntipp.
        Antworte auf Deutsch, maximal 100 Wörter.
        """

        let aiResult = try await ClaudeService.callAI(prompt: prompt, req: req)

        return ExerciseSubmitResponse(
            correctCount: input.correctCount,
            totalCount: input.totalCount,
            feedback: aiResult.text,
            modelUsed: aiResult.model
        )
    }

    // MARK: - Prompt Builders

    private func buildExercisePrompt(type: String, difficulty: Int, vocabItems: [VocabItem]) -> String {
        let vocabList = vocabItems.prefix(15).map { item in
            var entry = "- \(item.english) = \(item.german)"
            if let ex = item.exampleSentence { entry += " (Beispiel: \(ex))" }
            return entry
        }.joined(separator: "\n")

        let diffLabel = ["leicht", "mittel", "schwer"][min(difficulty - 1, 2)]

        switch type {
        case "dialogue":
            return """
            Erstelle eine Vokabelübung als Dialog. Schwierigkeit: \(diffLabel).

            Vokabeln:
            \(vocabList)

            Erstelle einen kurzen, interessanten Dialog (4-6 Zeilen) auf Englisch, \
            der diese Vokabeln verwendet. Für jede Vokabel im Dialog soll der Schüler \
            aus 3 Optionen die richtige wählen.

            Antworte NUR als JSON-Objekt in diesem Format:
            {
              "title": "Dialog-Titel",
              "lines": [
                {
                  "speaker": "A",
                  "text": "Satz mit ___",
                  "blank": "richtige Antwort",
                  "options": ["option1", "option2", "option3"],
                  "correctIndex": 0
                }
              ]
            }
            """

        case "progressive":
            return """
            Erstelle eine progressive Vokabelübung. Schwierigkeit: \(diffLabel).

            Vokabeln:
            \(vocabList)

            Für jedes Wort gibt es 3 Stufen:
            1. Die ersten 2 Buchstaben sind sichtbar → Schüler wählt aus 3 Optionen
            2. Nur 1 Buchstabe sichtbar → Schüler tippt die Antwort
            3. Kein Hinweis → Schüler tippt das Wort frei

            Antworte NUR als JSON-Objekt:
            {
              "title": "Wort-Entdecker",
              "words": [
                {
                  "english": "word",
                  "german": "Wort",
                  "hint2": "wo",
                  "hint1": "w",
                  "options": ["word", "work", "world"]
                }
              ]
            }

            Verwende maximal 8 Wörter.
            """

        case "context":
            return """
            Erstelle einen Lückentext mit Vokabeln. Schwierigkeit: \(diffLabel).

            Vokabeln:
            \(vocabList)

            Schreibe einen kurzen, interessanten Text (Thema: Wissenschaft, Geschichte oder Natur) \
            auf Englisch, der diese Vokabeln enthält. Ersetze die Vokabeln durch Lücken.

            Antworte NUR als JSON-Objekt:
            {
              "title": "Text-Titel",
              "text": "Text mit {0} und {1} als Lücken-Marker",
              "blanks": [
                {
                  "index": 0,
                  "answer": "richtige Antwort",
                  "german": "deutsche Übersetzung"
                }
              ]
            }

            Verwende maximal 6 Lücken.
            """

        default:
            return """
            Erstelle eine einfache Vokabelübung. Schwierigkeit: \(diffLabel).

            Vokabeln:
            \(vocabList)

            Antworte als JSON mit Fragen und Multiple-Choice-Antworten.
            """
        }
    }
}
