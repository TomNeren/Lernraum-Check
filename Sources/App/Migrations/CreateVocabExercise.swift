import Fluent

struct CreateVocabExercise: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("vocab_exercises")
            .id()
            .field("exercise_type", .string, .required)
            .field("topic", .string, .required)
            .field("difficulty", .int, .required)
            .field("content_json", .string, .required)
            .field("model_used", .string, .required)
            .field("created_at", .datetime)
            .field("expires_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("vocab_exercises").delete()
    }
}
