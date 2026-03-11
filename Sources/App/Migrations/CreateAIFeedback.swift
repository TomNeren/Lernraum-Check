import Fluent

struct CreateAIFeedback: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("ai_feedbacks")
            .id()
            .field("player_id", .uuid, .required, .references("players", "id"))
            .field("session_id", .uuid, .references("game_sessions", "id"))
            .field("feedback_type", .string, .required)
            .field("prompt_used", .string, .required)
            .field("ai_response", .string, .required)
            .field("score_before", .int)
            .field("score_after", .int)
            .field("model_used", .string, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("ai_feedbacks").delete()
    }
}
