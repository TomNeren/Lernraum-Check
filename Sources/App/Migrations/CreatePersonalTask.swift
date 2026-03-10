import Fluent

struct CreatePersonalTask: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("personal_tasks")
            .id()
            .field("player_id", .uuid, .required, .references("players", "id"))
            .field("title", .string, .required)
            .field("type", .string, .required)
            .field("config", .json, .required)
            .field("assigned_at", .datetime)
            .field("completed", .bool, .required)
            .field("completed_at", .datetime)
            .field("due_date", .datetime)
            .field("note", .string)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("personal_tasks").delete()
    }
}
