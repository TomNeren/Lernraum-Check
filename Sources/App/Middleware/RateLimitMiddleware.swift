import Vapor

/// Simple in-memory rate limiter based on client IP.
/// Tracks request counts per IP within a sliding time window.
final class RateLimitMiddleware: AsyncMiddleware, Sendable {
    private let storage: RateLimitStorage
    private let maxRequests: Int
    private let windowSeconds: Int

    /// - Parameters:
    ///   - maxRequests: Maximum number of requests allowed within the window.
    ///   - windowSeconds: Time window in seconds.
    init(maxRequests: Int, windowSeconds: Int) {
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
        self.storage = RateLimitStorage()
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let clientIP = request.headers.first(name: "X-Forwarded-For")
            ?? request.remoteAddress?.ipAddress
            ?? "unknown"

        let now = Date()
        let allowed = await storage.checkAndIncrement(
            key: clientIP,
            maxRequests: maxRequests,
            window: TimeInterval(windowSeconds),
            now: now
        )

        guard allowed else {
            throw Abort(.tooManyRequests, reason: "Zu viele Anfragen. Bitte warte einen Moment.")
        }

        return try await next.respond(to: request)
    }
}

/// Thread-safe storage for rate limit tracking.
private actor RateLimitStorage {
    private var entries: [String: [Date]] = [:]
    private var lastCleanup = Date()

    func checkAndIncrement(key: String, maxRequests: Int, window: TimeInterval, now: Date) -> Bool {
        // Periodic cleanup every 5 minutes
        if now.timeIntervalSince(lastCleanup) > 300 {
            cleanup(before: now.addingTimeInterval(-window))
            lastCleanup = now
        }

        let cutoff = now.addingTimeInterval(-window)
        var timestamps = entries[key, default: []].filter { $0 > cutoff }

        if timestamps.count >= maxRequests {
            return false
        }

        timestamps.append(now)
        entries[key] = timestamps
        return true
    }

    private func cleanup(before cutoff: Date) {
        for (key, timestamps) in entries {
            let filtered = timestamps.filter { $0 > cutoff }
            if filtered.isEmpty {
                entries.removeValue(forKey: key)
            } else {
                entries[key] = filtered
            }
        }
    }
}
