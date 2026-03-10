import Fluent
import Vapor

final class Klasse: Model, Content, @unchecked Sendable {
    static let schema = "klassen"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Children(for: \.$klasse)
    var lessonCodes: [LessonCode]

    init() {}

    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
