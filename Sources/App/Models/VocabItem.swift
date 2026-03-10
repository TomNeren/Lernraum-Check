import Fluent
import Vapor

final class VocabItem: Model, Content, @unchecked Sendable {
    static let schema = "vocab_items"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "english")
    var english: String

    @Field(key: "german")
    var german: String

    @OptionalField(key: "example_sentence")
    var exampleSentence: String?

    @OptionalField(key: "topic")
    var topic: String?

    @Field(key: "difficulty")
    var difficulty: Int

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, english: String, german: String, example: String? = nil, topic: String? = nil, difficulty: Int = 1) {
        self.id = id
        self.english = english
        self.german = german
        self.exampleSentence = example
        self.topic = topic
        self.difficulty = difficulty
    }
}
