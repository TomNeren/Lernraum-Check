import Fluent

struct CreatePlayer: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("players")
            .id()
            .field("name", .string, .required)
            .field("klasse", .string, .required)
            .field("created_at", .datetime)
            .field("last_seen", .datetime, .required)
            .unique(on: "name", "klasse")  // Name + Klasse = eindeutig
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("players").delete()
    }
}

struct CreateGameModule: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("game_modules")
            .id()
            .field("type", .string, .required)
            .field("title", .string, .required)
            .field("kompetenz", .string)
            .field("ls_number", .int)
            .field("solo_level", .string)
            .field("config", .json, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("game_modules").delete()
    }
}

struct CreateGameSession: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("game_sessions")
            .id()
            .field("player_id", .uuid, .required, .references("players", "id"))
            .field("module_id", .uuid, .required, .references("game_modules", "id"))
            .field("score", .int, .required)
            .field("max_score", .int, .required)
            .field("time_spent", .int, .required)
            .field("details", .json)
            .field("completed_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("game_sessions").delete()
    }
}
