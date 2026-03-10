import Fluent
import Vapor

final class ChatMessage: Model, Content, @unchecked Sendable {
    static let schema = "chat_messages"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "player_id")
    var player: Player

    @Field(key: "message")
    var message: String

    @Field(key: "klasse")
    var klasse: String

    @Field(key: "created_at")
    var createdAt: Date

    @OptionalField(key: "read_at")
    var readAt: Date?

    init() {}

    init(id: UUID? = nil, playerID: UUID, message: String, klasse: String) {
        self.id = id
        self.$player.id = playerID
        self.message = message
        self.klasse = klasse
        self.createdAt = Date()
    }
}
