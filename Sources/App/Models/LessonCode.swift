import Fluent
import Vapor

final class LessonCode: Model, Content, @unchecked Sendable {
    static let schema = "lesson_codes"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "klasse_id")
    var klasse: Klasse

    @Field(key: "code")
    var code: String

    @Field(key: "created_at_field")
    var createdAtField: Date

    @Field(key: "expires_at")
    var expiresAt: Date

    @Field(key: "active")
    var active: Bool

    init() {}

    init(id: UUID? = nil, klasseID: UUID, code: String, durationMinutes: Int = 90) {
        self.id = id
        self.$klasse.id = klasseID
        self.code = code
        self.createdAtField = Date()
        self.expiresAt = Date().addingTimeInterval(Double(durationMinutes) * 60)
        self.active = true
    }

    var isValid: Bool {
        return active && expiresAt > Date()
    }
}
