import Fluent

struct CreateKlasse: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("klassen")
            .id()
            .field("name", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "name")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("klassen").delete()
    }
}

struct CreateLessonCode: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("lesson_codes")
            .id()
            .field("klasse_id", .uuid, .required, .references("klassen", "id"))
            .field("code", .string, .required)
            .field("created_at_field", .datetime, .required)
            .field("expires_at", .datetime, .required)
            .field("active", .bool, .required)
            .unique(on: "code")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("lesson_codes").delete()
    }
}
