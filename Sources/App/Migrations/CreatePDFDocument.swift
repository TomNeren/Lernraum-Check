import Fluent

struct CreatePDFDocument: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("pdf_documents")
            .id()
            .field("title", .string, .required)
            .field("filename", .string, .required)
            .field("category", .string, .required)
            .field("klasse", .string)
            .field("subject", .string)
            .field("description", .string)
            .field("file_size", .int, .required)
            .field("uploaded_by", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("pdf_documents").delete()
    }
}
