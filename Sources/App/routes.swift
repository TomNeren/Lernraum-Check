import Vapor

func routes(_ app: Application) throws {
    // API-Controller registrieren
    try app.register(collection: PlayerController())
    try app.register(collection: GameController())
    try app.register(collection: LernraumController())
    try app.register(collection: VocabController())
    try app.register(collection: PersonalTaskController())
    try app.register(collection: AdminController())
    try app.register(collection: LessonCodeController())
    try app.register(collection: ChatController())
    try app.register(collection: PDFController())
    try app.register(collection: AIFeedbackController())
    try app.register(collection: VocabExerciseController())
    try app.register(collection: BadgeController())
    try app.register(collection: MaterialController())

    // Health-Check
    app.get("api", "health") { req -> String in
        return "LernHub v0.2.0 — OK"
    }

    // Redirect /admin → /admin/index.html (FileMiddleware bedient nur Dateien, nicht Verzeichnisse)
    app.get("admin") { req -> Response in
        return req.redirect(to: "/admin/index.html")
    }

    // Redirect root zu index.html (wird von FileMiddleware bedient)
    // FileMiddleware bedient automatisch Public/index.html für /
}
