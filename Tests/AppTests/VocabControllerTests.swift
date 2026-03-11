import XCTVapor
import Fluent
import FluentSQLiteDriver
@testable import App

final class VocabControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try configure(app)

        // Ensure clean DB state before each test
        try await VocabItem.query(on: app.db).delete()
    }

    override func tearDown() async throws {
        // Clean up
        try await VocabItem.query(on: app.db).delete()
        try await app.asyncShutdown()
    }

    func testGetTopics() async throws {
        // Arrange: Insert mock vocab items
        let item1 = VocabItem(english: "cat", german: "Katze", topic: "Animals", difficulty: 1)
        let item2 = VocabItem(english: "dog", german: "Hund", topic: "Animals", difficulty: 1) // Duplicate topic
        let item3 = VocabItem(english: "red", german: "rot", topic: "Colors", difficulty: 1)
        let item4 = VocabItem(english: "run", german: "rennen", topic: nil, difficulty: 1) // Nil topic should be ignored

        try await item1.save(on: app.db)
        try await item2.save(on: app.db)
        try await item3.save(on: app.db)
        try await item4.save(on: app.db)

        // Act: Test the getTopics route
        try await app.test(.GET, "api/vocab/topics") { res in
            // Assert: Verify status code
            XCTAssertEqual(res.status, .ok)

            // Assert: Decode the response to [String]
            let topics = try res.content.decode([String].self)

            // Should ignore the nil topic, remove duplicate "Animals",
            // and return sorted alphabetically: ["Animals", "Colors"]
            XCTAssertEqual(topics.count, 2)
            XCTAssertEqual(topics[0], "Animals")
            XCTAssertEqual(topics[1], "Colors")
        }
    }

    // MARK: - Review Card Tests (SM-2 / Leitner)

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
            // Assert
            XCTAssertEqual(res.status, .ok)
            let updatedProgress = try res.content.decode(VocabProgress.self)

            XCTAssertEqual(updatedProgress.repetitions, 0)
            XCTAssertEqual(updatedProgress.intervalDays, 0)
            XCTAssertEqual(updatedProgress.box, 2) // Max(1, box - 1) -> max(1, 3-1) = 2
            XCTAssertEqual(updatedProgress.correctStreak, 0)

            // SM-2: max(1.3, 2.5 + (0.1 - (3-0) * 0.08)) = 2.5 + 0.1 - 0.24 = 2.36
            XCTAssertEqual(updatedProgress.easeFactor, 2.36, accuracy: 0.001)
        })
    }

    func testReviewCard_Schwer() async throws {
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

        try app.test(.POST, "api/vocab/review", beforeRequest: { req in
            try req.content.encode(reviewRequest)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let updatedProgress = try res.content.decode(VocabProgress.self)

            XCTAssertEqual(updatedProgress.repetitions, 2) // 1 + 1
            XCTAssertEqual(updatedProgress.intervalDays, 1) // Fixed for 'Schwer'
            XCTAssertEqual(updatedProgress.box, 2) // Box remains the same
            XCTAssertEqual(updatedProgress.correctStreak, 0)
        })
    }

    func testReviewCard_Gut() async throws {
        let player = Player(name: "Test Player", klasse: "10A")
        try await player.save(on: app.db)
        let playerID = try XCTUnwrap(player.id)

        let vocabItem = VocabItem(english: "bird", german: "Vogel")
        try await vocabItem.save(on: app.db)
        let vocabID = try XCTUnwrap(vocabItem.id)

        let initialProgress = VocabProgress(playerID: playerID, vocabID: vocabID)
        try await initialProgress.save(on: app.db) // Start state: rep=0, interval=0, box=1

        let reviewRequest = VocabReviewRequest(playerID: playerID, vocabID: vocabID, quality: 2) // Gut

        try app.test(.POST, "api/vocab/review", beforeRequest: { req in
            try req.content.encode(reviewRequest)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let updatedProgress = try res.content.decode(VocabProgress.self)

            XCTAssertEqual(updatedProgress.repetitions, 1) // 0 + 1
            XCTAssertEqual(updatedProgress.box, 2) // min(5, 1+1)
            XCTAssertEqual(updatedProgress.correctStreak, 1)
            XCTAssertEqual(updatedProgress.intervalDays, 1) // First index in [1, 3, 7, 14, 30]
        })
    }

    func testReviewCard_Leicht() async throws {
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

        try app.test(.POST, "api/vocab/review", beforeRequest: { req in
            try req.content.encode(reviewRequest)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let updatedProgress = try res.content.decode(VocabProgress.self)

            XCTAssertEqual(updatedProgress.repetitions, 2) // 1 + 1
            XCTAssertEqual(updatedProgress.box, 3) // min(5, 2+1)
            XCTAssertEqual(updatedProgress.correctStreak, 2) // 1 + 1
            XCTAssertEqual(updatedProgress.intervalDays, 7) // max(1, Int(Double(max(1, 3)) * 2.5)) = 7
        })
    }

    func testReviewCard_NotFound() async throws {
        let fakePlayerID = UUID()
        let fakeVocabID = UUID()
        let reviewRequest = VocabReviewRequest(playerID: fakePlayerID, vocabID: fakeVocabID, quality: 2)

        try app.test(.POST, "api/vocab/review", beforeRequest: { req in
            try req.content.encode(reviewRequest)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }
}
