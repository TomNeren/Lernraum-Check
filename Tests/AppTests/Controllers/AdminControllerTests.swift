import XCTVapor
@testable import App

final class AdminControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
        try await app.autoMigrate()
    }

    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
    }

    func testAdminLoginSuccess() async throws {
        let password = Environment.get("ADMIN_PASSWORD") ?? "lernspiel2026"
        let req = AdminLoginRequest(password: password)

        try app.test(.POST, "api/admin/login", beforeRequest: { request in
            try request.content.encode(req)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            let resBody = try response.content.decode(AdminLoginResponse.self)
            XCTAssertNotNil(resBody.token)
            XCTAssertEqual(resBody.message, "Erfolgreich angemeldet.")
        })
    }

    func testAdminLoginFailureWithIncorrectPassword() async throws {
        let req = AdminLoginRequest(password: "wrong_password")

        try app.test(.POST, "api/admin/login", beforeRequest: { request in
            try request.content.encode(req)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .unauthorized)
        })
    }

    func testAdminLoginFailureWithMissingBody() async throws {
        try app.test(.POST, "api/admin/login", afterResponse: { response in
            XCTAssertEqual(response.status, .unsupportedMediaType)
        })
    }
}
