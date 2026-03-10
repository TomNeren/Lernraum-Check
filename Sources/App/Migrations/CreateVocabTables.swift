import Fluent

struct CreateVocabTables: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("vocab_items")
            .id()
            .field("english", .string, .required)
            .field("german", .string, .required)
            .field("example_sentence", .string)
            .field("topic", .string)
            .field("difficulty", .int, .required)
            .field("created_at", .datetime)
            .unique(on: "english", "german")
            .create()

        try await database.schema("vocab_progress")
            .id()
            .field("player_id", .uuid, .required, .references("players", "id"))
            .field("vocab_id", .uuid, .required, .references("vocab_items", "id"))
            .field("box", .int, .required)
            .field("ease_factor", .double, .required)
            .field("interval_days", .int, .required)
            .field("next_review", .datetime, .required)
            .field("repetitions", .int, .required)
            .field("correct_streak", .int, .required)
            .unique(on: "player_id", "vocab_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("vocab_progress").delete()
        try await database.schema("vocab_items").delete()
    }
}
