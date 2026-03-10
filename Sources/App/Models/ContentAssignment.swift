import Fluent
import Vapor

/// Generic assignment: assigns content (vocab topics, games) to classes or individual players.
/// content_type: "vocab-topic" or "game"
/// content_value: topic name (String) or game UUID (String)
/// Exactly one of klasse or player_id should be set.
final class ContentAssignment: Model, Content, @unchecked Sendable {
    static let schema = "content_assignments"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "content_type")
    var contentType: String

    @Field(key: "content_value")
    var contentValue: String

    @OptionalField(key: "klasse")
    var klasse: String?

    @OptionalField(key: "player_id")
    var playerID: UUID?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, contentType: String, contentValue: String, klasse: String? = nil, playerID: UUID? = nil) {
        self.id = id
        self.contentType = contentType
        self.contentValue = contentValue
        self.klasse = klasse
        self.playerID = playerID
    }
}
