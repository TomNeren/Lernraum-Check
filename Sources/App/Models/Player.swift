import Fluent
import Vapor

final class Player: Model, Content, @unchecked Sendable {
    static let schema = "players"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "klasse")
    var klasse: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Field(key: "last_seen")
    var lastSeen: Date

    @Children(for: \.$player)
    var sessions: [GameSession]

    init() {}

    init(id: UUID? = nil, name: String, klasse: String) {
        self.id = id
        self.name = name
        self.klasse = klasse
        self.lastSeen = Date()
    }
}
