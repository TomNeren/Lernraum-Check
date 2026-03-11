import Fluent

struct CreateChatMessage: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("chat_messages")
            .id()
            .field("player_id", .uuid, .required, .references("players", "id"))
            .field("message", .string, .required)
            .field("klasse", .string, .required)
            .field("created_at", .datetime, .required)
            .field("read_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("chat_messages").delete()
    }
}
