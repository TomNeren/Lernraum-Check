import Vapor

/// Middleware that validates the admin token from the Authorization header.
/// The token must match the format generated at login: base64(password + date).
/// Usage: group sensitive admin routes behind this middleware.
struct AdminAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Extract token from Authorization header: "Bearer <token>"
        guard let authHeader = request.headers[.authorization].first,
              authHeader.lowercased().hasPrefix("bearer ") else {
            throw Abort(.unauthorized, reason: "Kein Authentifizierungs-Token angegeben.")
        }

        let token = String(authHeader.dropFirst("Bearer ".count)).trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty else {
            throw Abort(.unauthorized, reason: "Leeres Token.")
        }

        // Validate: decode the token and check if it contains the admin password
        let adminPassword = Environment.get("ADMIN_PASSWORD") ?? "lernspiel2026"
        guard let decoded = Data(base64Encoded: token),
              let decodedString = String(data: decoded, encoding: .utf8),
              decodedString.hasPrefix(adminPassword) else {
            throw Abort(.unauthorized, reason: "Ungültiges Token. Bitte erneut anmelden.")
        }

        return try await next.respond(to: request)
    }
}
