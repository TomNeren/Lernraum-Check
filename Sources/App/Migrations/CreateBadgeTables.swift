import Fluent

struct CreateBadgeTables: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("badges")
            .id()
            .field("name", .string, .required)
            .field("description", .string, .required)
            .field("icon", .string, .required)
            .field("category", .string, .required)
            .field("requirement_type", .string, .required)
            .field("requirement_value", .int, .required)
            .field("created_at", .datetime)
            .create()

        try await database.schema("player_badges")
            .id()
            .field("player_id", .uuid, .required, .references("players", "id"))
            .field("badge_id", .uuid, .required, .references("badges", "id"))
            .field("earned_at", .datetime)
            .unique(on: "player_id", "badge_id")
            .create()

        // Seed default badges
        let badges: [(String, String, String, String, String, Int)] = [
            ("Erster Schritt", "Erstes Spiel gespielt", "⭐", "games", "games_played", 1),
            ("Spieler", "5 Spiele gespielt", "🎮", "games", "games_played", 5),
            ("Profi-Spieler", "20 Spiele gespielt", "🏅", "games", "games_played", 20),
            ("Fleißig", "100 Punkte gesammelt", "🔥", "games", "total_score", 100),
            ("Punktejäger", "500 Punkte gesammelt", "💎", "games", "total_score", 500),
            ("Vokabel-Starter", "10 Vokabeln gelernt", "📖", "vocab", "vocab_reviewed", 10),
            ("Vokabel-Meister", "50 Vokabeln gemeistert", "🎯", "vocab", "vocab_mastered", 50),
            ("Perfektionist", "Ein Spiel mit 100% abgeschlossen", "💯", "special", "perfect_game", 1),
        ]

        for (name, desc, icon, cat, reqType, reqVal) in badges {
            let badge = Badge(name: name, description: desc, icon: icon,
                            category: cat, requirementType: reqType, requirementValue: reqVal)
            try await badge.save(on: database)
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema("player_badges").delete()
        try await database.schema("badges").delete()
    }
}
