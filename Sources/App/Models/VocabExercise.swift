import Fluent
import Vapor

final class VocabExercise: Model, Content, @unchecked Sendable {
    static let schema = "vocab_exercises"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "exercise_type")
    var exerciseType: String  // "dialogue", "progressive", "context"

    @Field(key: "topic")
    var topic: String

    @Field(key: "difficulty")
    var difficulty: Int  // 1-3

    @Field(key: "content_json")
    var contentJSON: String  // AI-generated exercise content as JSON

    @Field(key: "model_used")
    var modelUsed: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @OptionalField(key: "expires_at")
    var expiresAt: Date?

    init() {}

    init(id: UUID? = nil, exerciseType: String, topic: String, difficulty: Int,
         contentJSON: String, modelUsed: String, expiresAt: Date? = nil) {
        self.id = id
        self.exerciseType = exerciseType
        self.topic = topic
        self.difficulty = difficulty
        self.contentJSON = contentJSON
        self.modelUsed = modelUsed
        self.expiresAt = expiresAt
    }
}
