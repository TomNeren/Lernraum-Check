import Fluent
import Vapor

final class AIFeedback: Model, Content, @unchecked Sendable {
    static let schema = "ai_feedbacks"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "player_id")
    var player: Player

    @OptionalParent(key: "session_id")
    var session: GameSession?

    @Field(key: "feedback_type")
    var feedbackType: String  // "game_review", "vocab_tip", "general", "error_analysis"

    @Field(key: "prompt_used")
    var promptUsed: String

    @Field(key: "ai_response")
    var aiResponse: String

    @OptionalField(key: "score_before")
    var scoreBefore: Int?

    @OptionalField(key: "score_after")
    var scoreAfter: Int?

    @Field(key: "model_used")
    var modelUsed: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, playerID: UUID, sessionID: UUID? = nil,
         feedbackType: String, promptUsed: String, aiResponse: String,
         scoreBefore: Int? = nil, scoreAfter: Int? = nil, modelUsed: String) {
        self.id = id
        self.$player.id = playerID
        if let sid = sessionID {
            self.$session.id = sid
        }
        self.feedbackType = feedbackType
        self.promptUsed = promptUsed
        self.aiResponse = aiResponse
        self.scoreBefore = scoreBefore
        self.scoreAfter = scoreAfter
        self.modelUsed = modelUsed
    }
}
