import Fluent
import Vapor

final class SystemPrompt: Model, Content, @unchecked Sendable {
    static let schema = "system_prompts"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "key")
    var key: String  // e.g. "material_feedback"

    @Field(key: "prompt_text")
    var promptText: String

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, key: String, promptText: String) {
        self.id = id
        self.key = key
        self.promptText = promptText
    }
}
