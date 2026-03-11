import XCTVapor
import Fluent
import FluentSQLiteDriver
@testable import App

final class VocabControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = Application(.testing)

        // --- Database Setup ---
        app.databases.use(.sqlite(.memory), as: .sqlite)

        // --- Migrations Setup ---
        // Need to add all necessary migrations for models we'll use: Player, VocabItem, VocabProgress
        app.migrations.add(CreatePlayer())
        app.migrations.add(CreateVocabTables()) // Creates vocab_items and vocab_progress
        try await app.autoMigrate()

        try app.register(collection: VocabController())
    }

    override func tearDown() async throws {
        app.shutdown()
    }

    func testReviewCard_Nochmal() async throws {
        // Arrange
        let player = Player(name: "Test Player", klasse: "10A")
        try await player.save(on: app.db)
        let playerID = try XCTUnwrap(player.id)

        let vocabItem = VocabItem(english: "cat", german: "Katze", example: nil, topic: nil, difficulty: 1)
        try await vocabItem.save(on: app.db)
        let vocabID = try XCTUnwrap(vocabItem.id)

        let initialProgress = VocabProgress(playerID: playerID, vocabID: vocabID)
        initialProgress.box = 3
        initialProgress.easeFactor = 2.5
        initialProgress.intervalDays = 7
        initialProgress.repetitions = 2
        initialProgress.correctStreak = 2
        try await initialProgress.save(on: app.db)

        let reviewRequest = VocabReviewRequest(playerID: playerID, vocabID: vocabID, quality: 0) // Nochmal

        // Act
        try app.test(.POST, "api/vocab/review", beforeRequest: { req in
            try req.content.encode(reviewRequest)
        }, afterResponse: { res in
            // Assert API Response
            XCTAssertEqual(res.status, .ok)
            let updatedProgress = try res.content.decode(VocabProgress.self)

            // Assert Progress Logic
            XCTAssertEqual(updatedProgress.repetitions, 0)
            XCTAssertEqual(updatedProgress.intervalDays, 0)
            XCTAssertEqual(updatedProgress.box, 2) // Max(1, box - 1) -> max(1, 3-1) = 2
            XCTAssertEqual(updatedProgress.correctStreak, 0)

            // Expected Ease Factor logic from SM-2: max(1.3, easeFactor + (0.1 - (3-quality) * 0.08))
            // max(1.3, 2.5 + (0.1 - (3-0) * 0.08)) = 2.5 + 0.1 - 0.24 = 2.36
            XCTAssertEqual(updatedProgress.easeFactor, 2.36, accuracy: 0.001)
        })
    }

    func testReviewCard_Schwer() async throws {
        // Arrange
        let player = Player(name: "Test Player", klasse: "10A")
        try await player.save(on: app.db)
        let playerID = try XCTUnwrap(player.id)

        let vocabItem = VocabItem(english: "dog", german: "Hund")
        try await vocabItem.save(on: app.db)
        let vocabID = try XCTUnwrap(vocabItem.id)

        let initialProgress = VocabProgress(playerID: playerID, vocabID: vocabID)
        initialProgress.box = 2
        initialProgress.easeFactor = 2.5
        initialProgress.intervalDays = 3
        initialProgress.repetitions = 1
        initialProgress.correctStreak = 1
        try await initialProgress.save(on: app.db)

        let reviewRequest = VocabReviewRequest(playerID: playerID, vocabID: vocabID, quality: 1) // Schwer

        // Act
        try app.test(.POST, "api/vocab/review", beforeRequest: { req in
            try req.content.encode(reviewRequest)
        }, afterResponse: { res in
            // Assert API Response
            XCTAssertEqual(res.status, .ok)
            let updatedProgress = try res.content.decode(VocabProgress.self)

            // Assert Progress Logic
            XCTAssertEqual(updatedProgress.repetitions, 2) // 1 + 1
            XCTAssertEqual(updatedProgress.intervalDays, 1) // Fixed for 'Schwer'
            XCTAssertEqual(updatedProgress.box, 2) // Box remains the same
            XCTAssertEqual(updatedProgress.correctStreak, 0)
        })
    }

    func testReviewCard_Gut() async throws {
        // Arrange
        let player = Player(name: "Test Player", klasse: "10A")
        try await player.save(on: app.db)
        let playerID = try XCTUnwrap(player.id)

        let vocabItem = VocabItem(english: "bird", german: "Vogel")
        try await vocabItem.save(on: app.db)
        let vocabID = try XCTUnwrap(vocabItem.id)

        let initialProgress = VocabProgress(playerID: playerID, vocabID: vocabID)
        try await initialProgress.save(on: app.db) // Start state: rep=0, interval=0, box=1

        let reviewRequest = VocabReviewRequest(playerID: playerID, vocabID: vocabID, quality: 2) // Gut

        // Act
        try app.test(.POST, "api/vocab/review", beforeRequest: { req in
            try req.content.encode(reviewRequest)
        }, afterResponse: { res in
            // Assert API Response
            XCTAssertEqual(res.status, .ok)
            let updatedProgress = try res.content.decode(VocabProgress.self)

            // Assert Progress Logic
            XCTAssertEqual(updatedProgress.repetitions, 1) // 0 + 1
            XCTAssertEqual(updatedProgress.box, 2) // min(5, 1+1)
            XCTAssertEqual(updatedProgress.correctStreak, 1)
            XCTAssertEqual(updatedProgress.intervalDays, 1) // First index in [1, 3, 7, 14, 30] -> index 0 (rep 1 - 1 = 0)
        })
    }

    func testReviewCard_Leicht() async throws {
        // Arrange
        let player = Player(name: "Test Player", klasse: "10A")
        try await player.save(on: app.db)
        let playerID = try XCTUnwrap(player.id)

        let vocabItem = VocabItem(english: "fish", german: "Fisch")
        try await vocabItem.save(on: app.db)
        let vocabID = try XCTUnwrap(vocabItem.id)

        let initialProgress = VocabProgress(playerID: playerID, vocabID: vocabID)
        initialProgress.box = 2
        initialProgress.easeFactor = 2.5
        initialProgress.intervalDays = 3
        initialProgress.repetitions = 1
        initialProgress.correctStreak = 1
        try await initialProgress.save(on: app.db)

        let reviewRequest = VocabReviewRequest(playerID: playerID, vocabID: vocabID, quality: 3) // Leicht

        // Act
        try app.test(.POST, "api/vocab/review", beforeRequest: { req in
            try req.content.encode(reviewRequest)
        }, afterResponse: { res in
            // Assert API Response
            XCTAssertEqual(res.status, .ok)
            let updatedProgress = try res.content.decode(VocabProgress.self)

            // Assert Progress Logic
            XCTAssertEqual(updatedProgress.repetitions, 2) // 1 + 1
            XCTAssertEqual(updatedProgress.box, 3) // min(5, 2+1)
            XCTAssertEqual(updatedProgress.correctStreak, 2) // 1 + 1
            XCTAssertEqual(updatedProgress.intervalDays, 7) // max(1, Int(Double(max(1, 3)) * 2.5)) = Int(3 * 2.5) = Int(7.5) = 7
        })
    }

    func testReviewCard_NotFound() async throws {
        // Arrange
        let fakePlayerID = UUID()
        let fakeVocabID = UUID()
        let reviewRequest = VocabReviewRequest(playerID: fakePlayerID, vocabID: fakeVocabID, quality: 2)

        // Act
        try app.test(.POST, "api/vocab/review", beforeRequest: { req in
            try req.content.encode(reviewRequest)
        }, afterResponse: { res in
            // Assert API Response
            XCTAssertEqual(res.status, .notFound)
        })
    }
}
