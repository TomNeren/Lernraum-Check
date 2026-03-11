import Vapor
import Fluent

struct ChatController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let chat = routes.grouped("api", "chat")

        // Student endpoints — rate limited (10 messages per minute)
        let rateLimited = chat.grouped(RateLimitMiddleware(maxRequests: 10, windowSeconds: 60))
        rateLimited.post("send", use: sendMessage)
        chat.get("my", ":playerID", use: getMyMessages)

        // Admin endpoints — protected
        let protected = chat.grouped(AdminAuthMiddleware())
        protected.get("all", use: getAllMessages)
        protected.get("klasse", ":klasse", use: getMessagesByKlasse)
        protected.get("unread", use: getUnreadCount)
        protected.put(":messageID", "read", use: markAsRead)
        protected.post("read-all", use: markAllAsRead)
    }

    // MARK: - Student: Send a message

    // POST /api/chat/send
    @Sendable
    func sendMessage(req: Request) async throws -> ChatMessage {
        let input = try req.content.decode(SendChatRequest.self)

        // Validate player exists
        guard let player = try await Player.find(input.playerID, on: req.db) else {
            throw Abort(.notFound, reason: "Spieler nicht gefunden.")
        }

        // Limit message length
        let trimmed = input.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw Abort(.badRequest, reason: "Nachricht darf nicht leer sein.")
        }
        guard trimmed.count <= 500 else {
            throw Abort(.badRequest, reason: "Nachricht darf maximal 500 Zeichen lang sein.")
        }

        let message = ChatMessage(
            playerID: player.id!,
            message: trimmed,
            klasse: player.klasse
        )
        try await message.save(on: req.db)
        return message
    }

    // MARK: - Student: Get own messages

    // GET /api/chat/my/:playerID
    @Sendable
    func getMyMessages(req: Request) async throws -> [ChatMessageResponse] {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        let messages = try await ChatMessage.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .sort(\.$createdAt, .descending)
            .range(..<20)
            .with(\.$player)
            .all()

        return messages.map { msg in
            ChatMessageResponse(
                id: msg.id!,
                playerName: msg.player.name,
                klasse: msg.klasse,
                message: msg.message,
                createdAt: msg.createdAt,
                readAt: msg.readAt
            )
        }
    }

    // MARK: - Admin: Get all messages

    // GET /api/chat/all
    @Sendable
    func getAllMessages(req: Request) async throws -> [ChatMessageResponse] {
        let messages = try await ChatMessage.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .range(..<100)
            .with(\.$player)
            .all()

        return messages.map { msg in
            ChatMessageResponse(
                id: msg.id!,
                playerName: msg.player.name,
                klasse: msg.klasse,
                message: msg.message,
                createdAt: msg.createdAt,
                readAt: msg.readAt
            )
        }
    }

    // GET /api/chat/klasse/:klasse
    @Sendable
    func getMessagesByKlasse(req: Request) async throws -> [ChatMessageResponse] {
        guard let klasse = req.parameters.get("klasse") else {
            throw Abort(.badRequest)
        }

        let messages = try await ChatMessage.query(on: req.db)
            .filter(\.$klasse == klasse)
            .sort(\.$createdAt, .descending)
            .range(..<100)
            .with(\.$player)
            .all()

        return messages.map { msg in
            ChatMessageResponse(
                id: msg.id!,
                playerName: msg.player.name,
                klasse: msg.klasse,
                message: msg.message,
                createdAt: msg.createdAt,
                readAt: msg.readAt
            )
        }
    }

    // GET /api/chat/unread
    @Sendable
    func getUnreadCount(req: Request) async throws -> UnreadCountResponse {
        let count = try await ChatMessage.query(on: req.db)
            .filter(\.$readAt == nil)
            .count()

        return UnreadCountResponse(count: count)
    }

    // PUT /api/chat/:messageID/read
    @Sendable
    func markAsRead(req: Request) async throws -> HTTPStatus {
        guard let messageID: UUID = req.parameters.get("messageID") else {
            throw Abort(.badRequest)
        }

        guard let message = try await ChatMessage.find(messageID, on: req.db) else {
            throw Abort(.notFound, reason: "Nachricht nicht gefunden.")
        }

        message.readAt = Date()
        try await message.save(on: req.db)
        return .ok
    }

    // POST /api/chat/read-all
    @Sendable
    func markAllAsRead(req: Request) async throws -> HTTPStatus {
        let unread = try await ChatMessage.query(on: req.db)
            .filter(\.$readAt == nil)
            .all()

        for message in unread {
            message.readAt = Date()
            try await message.save(on: req.db)
        }

        return .ok
    }
}
