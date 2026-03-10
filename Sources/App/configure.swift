import Vapor
import Fluent
import FluentSQLiteDriver

func configure(_ app: Application) throws {
    // --- Environment ---
    // Load .env file if present
    loadDotEnv()

    // --- Upload limit ---
    let maxUploadMB = Int(Environment.get("MAX_UPLOAD_MB") ?? "10") ?? 10
    app.routes.defaultMaxBodySize = ByteCount(stringLiteral: "\(maxUploadMB)mb")

    // --- Storage directory for uploads ---
    let storagePath = app.directory.workingDirectory + "Storage"
    if !FileManager.default.fileExists(atPath: storagePath) {
        try FileManager.default.createDirectory(atPath: storagePath, withIntermediateDirectories: true)
    }

    // --- Database ---
    app.databases.use(.sqlite(.file("lernspiel.sqlite")), as: .sqlite)

    // --- Migrations ---
    app.migrations.add(CreatePlayer())
    app.migrations.add(CreateGameModule())
    app.migrations.add(CreateGameSession())
    app.migrations.add(CreateLernraumCheckin())
    app.migrations.add(CreateVocabTables())
    app.migrations.add(CreatePersonalTask())
    app.migrations.add(CreateKlasse())
    app.migrations.add(CreateLessonCode())
    app.migrations.add(CreateContentAssignment())
    try app.autoMigrate().wait()

    // --- Middleware ---
    // CORS für lokale Entwicklung
    let corsConfig = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfig))

    // Statische Dateien aus Public/
    app.middleware.use(FileMiddleware(
        publicDirectory: app.directory.publicDirectory,
        defaultFile: "index.html"
    ))

    // --- Routes ---
    try routes(app)
}

/// Load .env file into process environment
private func loadDotEnv() {
    let path = FileManager.default.currentDirectoryPath + "/.env"
    guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return }

    for line in contents.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

        let parts = trimmed.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else { continue }

        let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
        setenv(key, value, 1)
    }
}
