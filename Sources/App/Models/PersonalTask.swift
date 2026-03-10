import Fluent
import Vapor

final class PersonalTask: Model, Content, @unchecked Sendable {
    static let schema = "personal_tasks"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "player_id")
    var player: Player

    @Field(key: "title")
    var title: String

    @Field(key: "type")
    var type: String

    @Field(key: "config")
    var config: GameConfig

    @Timestamp(key: "assigned_at", on: .create)
    var assignedAt: Date?

    @Field(key: "completed")
    var completed: Bool

    @OptionalField(key: "completed_at")
    var completedAt: Date?

    @OptionalField(key: "due_date")
    var dueDate: Date?

    @OptionalField(key: "note")
    var note: String?

    init() {}

    init(id: UUID? = nil, playerID: UUID, title: String, type: String,
         config: GameConfig, dueDate: Date? = nil, note: String? = nil) {
        self.id = id
        self.$player.id = playerID
        self.title = title
        self.type = type
        self.config = config
        self.completed = false
        self.dueDate = dueDate
        self.note = note
    }
}
