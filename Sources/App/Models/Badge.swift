import Fluent
import Vapor

final class Badge: Model, Content, @unchecked Sendable {
    static let schema = "badges"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "description")
    var description: String

    @Field(key: "icon")
    var icon: String

    @Field(key: "category")
    var category: String  // "games", "vocab", "streak", "special"

    @Field(key: "requirement_type")
    var requirementType: String  // "games_played", "total_score", "vocab_mastered", etc.

    @Field(key: "requirement_value")
    var requirementValue: Int

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, name: String, description: String, icon: String,
         category: String, requirementType: String, requirementValue: Int) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.category = category
        self.requirementType = requirementType
        self.requirementValue = requirementValue
    }
}

final class PlayerBadge: Model, Content, @unchecked Sendable {
    static let schema = "player_badges"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "player_id")
    var player: Player

    @Parent(key: "badge_id")
    var badge: Badge

    @Timestamp(key: "earned_at", on: .create)
    var earnedAt: Date?

    init() {}

    init(id: UUID? = nil, playerID: UUID, badgeID: UUID) {
        self.id = id
        self.$player.id = playerID
        self.$badge.id = badgeID
    }
}
