import Vapor
import Fluent

struct BadgeController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let badges = routes.grouped("api", "badges")

        badges.get("player", ":playerID", use: getPlayerBadges)
        badges.post("check", ":playerID", use: checkBadges)
        badges.get("all", use: getAllBadges)
    }

    // GET /api/badges/player/:playerID
    @Sendable
    func getPlayerBadges(req: Request) async throws -> [PlayerBadgeResponse] {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        let allBadges = try await Badge.query(on: req.db).all()
        let earned = try await PlayerBadge.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .all()

        let earnedMap = Dictionary(uniqueKeysWithValues: earned.compactMap { pb -> (UUID, Date?)? in
            return (pb.$badge.id, pb.earnedAt)
        })

        return allBadges.map { badge in
            let isEarned = earnedMap[badge.id!] != nil
            return PlayerBadgeResponse(
                id: badge.id!,
                name: badge.name,
                icon: badge.icon,
                description: badge.description,
                earned: isEarned,
                earnedAt: isEarned ? earnedMap[badge.id!] ?? nil : nil
            )
        }
    }

    // POST /api/badges/check/:playerID
    @Sendable
    func checkBadges(req: Request) async throws -> BadgeCheckResponse {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        let newBadges = try await BadgeService.checkAndAward(playerID: playerID, db: req.db)

        return BadgeCheckResponse(
            newBadges: newBadges.map { badge in
                PlayerBadgeResponse(
                    id: badge.id!,
                    name: badge.name,
                    icon: badge.icon,
                    description: badge.description,
                    earned: true,
                    earnedAt: Date()
                )
            }
        )
    }

    // GET /api/badges/all
    @Sendable
    func getAllBadges(req: Request) async throws -> [BadgeDefinition] {
        let badges = try await Badge.query(on: req.db).all()
        return badges.map { badge in
            BadgeDefinition(
                id: badge.id!,
                name: badge.name,
                description: badge.description,
                icon: badge.icon,
                category: badge.category
            )
        }
    }
}
