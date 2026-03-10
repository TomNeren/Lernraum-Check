import Fluent
import Vapor

final class LernraumCheckin: Model, Content, @unchecked Sendable {
    static let schema = "lernraum_checkins"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "player_id")
    var player: Player

    @Field(key: "raum")
    var raum: String

    @Field(key: "checked_in_at")
    var checkedInAt: Date

    @OptionalField(key: "checked_out_at")
    var checkedOutAt: Date?

    init() {}

    init(id: UUID? = nil, playerID: UUID, raum: String) {
        self.id = id
        self.$player.id = playerID
        self.raum = raum
        self.checkedInAt = Date()
    }
}
