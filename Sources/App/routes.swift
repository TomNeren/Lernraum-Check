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

    // Health-Check
    app.get("api", "health") { req -> String in
        return "LernSpiel v0.1.0 — OK"
    }

    // Redirect root zu index.html (wird von FileMiddleware bedient)
    // FileMiddleware bedient automatisch Public/index.html für /
}
