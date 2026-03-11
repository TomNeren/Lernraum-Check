import XCTVapor
import Fluent
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
}
