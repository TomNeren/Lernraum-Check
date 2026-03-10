import Fluent

struct CreateLernraumCheckin: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("lernraum_checkins")
            .id()
            .field("player_id", .uuid, .required, .references("players", "id"))
            .field("raum", .string, .required)
            .field("checked_in_at", .datetime, .required)
            .field("checked_out_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("lernraum_checkins").delete()
    }
}
