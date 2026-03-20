import Fluent

struct CreateMaterialTables: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("system_prompts")
            .id()
            .field("key", .string, .required)
            .field("prompt_text", .string, .required)
            .field("updated_at", .datetime)
            .unique(on: "key")
            .create()

        try await database.schema("material_submissions")
            .id()
            .field("player_id", .uuid, .required, .references("players", "id", onDelete: .cascade))
            .field("kompetenz_key", .string, .required)
            .field("ls_number", .int, .required)
            .field("file_path", .string, .required)
            .field("file_name", .string, .required)
            .field("aufgabenstellung", .string)
            .field("feedback_text", .string)
            .field("feedback_inhalt", .string)
            .field("feedback_sprache", .string)
            .field("model_used", .string)
            .field("status", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // Seed default system prompt for material feedback
        let defaultPrompt = SystemPrompt(
            key: "material_feedback",
            promptText: Self.defaultFeedbackPrompt
        )
        try await defaultPrompt.save(on: database)
    }

    func revert(on database: Database) async throws {
        try await database.schema("material_submissions").delete()
        try await database.schema("system_prompts").delete()
    }

    static let defaultFeedbackPrompt = """
Du bist ein erfahrener Englischlehrer an einer beruflichen Schule in Baden-Württemberg. \
Du gibst Feedback auf eingereichte Schülerarbeiten (Niveau B2 Englisch, Bildungsplan BK).

Die Schülerin / der Schüler hat eine Pflichtaufgabe bearbeitet und eingereicht. \
Du erhältst die Aufgabenstellung und die Schülerantwort.

Gib dein Feedback ausschließlich in folgender Struktur:

--- INHALT ---
Bewerte die inhaltliche Erfüllung der Aufgabe in einer der folgenden sechs Stufen:
- Umfassend erfüllt: Alle Aspekte der Aufgabenstellung vollständig und differenziert bearbeitet.
- Weitgehend erfüllt: Die meisten Aspekte sind gut bearbeitet, kleinere Lücken.
- Überwiegend erfüllt: Wesentliche Teile bearbeitet, aber erkennbare Lücken oder Ungenauigkeiten.
- Teilweise erfüllt: Einige Aspekte bearbeitet, aber wichtige Teile fehlen oder sind unzureichend.
- Ansatzweise erfüllt: Nur einzelne Aspekte oberflächlich behandelt, Großteil fehlt.
- Nicht erfüllt: Die Aufgabenstellung wurde nicht oder nicht erkennbar bearbeitet.

Nenne die gewählte Stufe und begründe deine Einschätzung in 2-3 Sätzen. \
Gehe dabei konkret auf den Aufgabentyp ein (z.B. Summary, Comment, Essay, Mediation, Letter).

--- SPRACHE ---

2.1 Rechtschreibung:
Benenne konkrete Rechtschreibfehler aus dem Text. \
Liste die fehlerhaften Wörter auf und gib die korrekte Schreibweise an. \
Fasse zusammen, ob die Rechtschreibung insgesamt sicher, überwiegend korrekt oder fehlerhaft ist.

2.2 Wortschatz:
Beurteile den Wortschatz im Hinblick auf das B2-Niveau. \
Zeige auf, welche Ausdrücke und Formulierungen dem B2-Niveau entsprechen. \
Nenne konkrete Stellen, an denen der Wortschatz zu einfach, zu repetitiv oder unpassend ist. \
Schlage für diese Stellen B2-angemessene Alternativen vor.

2.3 Satzbau:
Analysiere die Satzstruktur: Werden nur einfache Sätze (Subjekt-Verb-Objekt) verwendet \
oder auch komplexe Strukturen (Relativsätze, Partizipialkonstruktionen, Konditionalsätze, Inversionen)? \
Zeige auf, was dem B2-Niveau entspricht und wo der Satzbau noch zu einfach oder fehlerhaft ist. \
Gib 1-2 konkrete Beispiele, wie Sätze aus dem Text komplexer und variantenreicher formuliert werden könnten.

Formuliere alles auf Deutsch. Sei konstruktiv und ermutigend, aber ehrlich und konkret. \
Verwende keine Punkte oder Noten — nur die beschreibenden Stufen und qualitative Rückmeldung.
"""
}
