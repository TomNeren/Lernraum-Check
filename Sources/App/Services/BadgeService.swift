import Vapor
import Fluent

struct BadgeService {

    /// Check all badges for a player and award any newly earned ones.
    /// Returns array of newly awarded badges.
    static func checkAndAward(playerID: UUID, db: Database) async throws -> [Badge] {
        let allBadges = try await Badge.query(on: db).all()
        let earnedBadgeIDs = try await PlayerBadge.query(on: db)
            .filter(\.$player.$id == playerID)
            .all()
            .map { $0.$badge.id }

        let unearned = allBadges.filter { badge in
            !earnedBadgeIDs.contains(badge.id!)
        }

        if unearned.isEmpty { return [] }

        // Gather player stats
        let sessionCount = try await GameSession.query(on: db)
            .filter(\.$player.$id == playerID)
            .count()

        let sessions = try await GameSession.query(on: db)
            .filter(\.$player.$id == playerID)
            .all()

        let totalScore = sessions.reduce(0) { $0 + $1.score }

        let hasPerfectGame = sessions.contains { session in
            session.maxScore > 0 && session.score == session.maxScore
        }

        // Vocab stats
        let vocabProgress = try await VocabProgress.query(on: db)
            .filter(\.$player.$id == playerID)
            .all()

        let vocabReviewed = vocabProgress.count
        let vocabMastered = vocabProgress.filter { $0.box >= 5 }.count

        // Check each unearned badge
        var newlyEarned: [Badge] = []

        for badge in unearned {
            let earned: Bool
            switch badge.requirementType {
            case "games_played":
                earned = sessionCount >= badge.requirementValue
            case "total_score":
                earned = totalScore >= badge.requirementValue
            case "vocab_reviewed":
                earned = vocabReviewed >= badge.requirementValue
            case "vocab_mastered":
                earned = vocabMastered >= badge.requirementValue
            case "perfect_game":
                earned = hasPerfectGame
            default:
                earned = false
            }

            if earned {
                let pb = PlayerBadge(playerID: playerID, badgeID: badge.id!)
                try await pb.save(on: db)
                newlyEarned.append(badge)
            }
        }

        return newlyEarned
    }
}
