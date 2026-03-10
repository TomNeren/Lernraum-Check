import Fluent
import Vapor

final class GameSession: Model, Content, @unchecked Sendable {
    static let schema = "game_sessions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "player_id")
    var player: Player

    @Parent(key: "module_id")
    var module: GameModule

    @Field(key: "score")
    var score: Int

    @Field(key: "max_score")
    var maxScore: Int

    @Field(key: "time_spent")
    var timeSpent: Int  // Sekunden

    // Detail-Daten: welche Fragen richtig/falsch
    @OptionalField(key: "details")
    var details: SessionDetails?

    @Timestamp(key: "completed_at", on: .create)
    var completedAt: Date?

    init() {}

    init(id: UUID? = nil, playerID: UUID, moduleID: UUID,
         score: Int, maxScore: Int, timeSpent: Int, details: SessionDetails? = nil) {
        self.id = id
        self.$player.id = playerID
        self.$module.id = moduleID
        self.score = score
        self.maxScore = maxScore
        self.timeSpent = timeSpent
        self.details = details
    }
}

struct SessionDetails: Codable {
    var answers: [AnswerDetail]
}

struct AnswerDetail: Codable {
    var questionID: UUID
    var givenAnswer: String
    var correct: Bool
    var timeTaken: Int  // Sekunden für diese Frage
}
