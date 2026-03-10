import Fluent

struct CreateContentAssignment: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("content_assignments")
            .id()
            .field("content_type", .string, .required)
            .field("content_value", .string, .required)
            .field("klasse", .string)
            .field("player_id", .uuid)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("content_assignments").delete()
    }
}
