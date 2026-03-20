import Foundation
import FoundationModels

// Minimal HTTP server bridging Apple Foundation Models
// Listens on port 8091, handles POST /generate

@available(macOS 26.0, *)
struct FMBridge {
    static let port: UInt16 = 8091

    static func main() async {
        print("🍎 FMBridge starting on port \(port)...")

        // Test that the model is available
        let session = LanguageModelSession()
        do {
            let test = try await session.respond(to: "Say OK")
            print("✅ Foundation Model ready: \(test.content.prefix(20))...")
        } catch {
            print("⚠️  Foundation Model not available: \(error)")
            print("   Will still start server, but requests will fail.")
        }

        // Start a basic HTTP server using POSIX sockets
        guard let serverSocket = createServerSocket(port: port) else {
            print("❌ Failed to bind to port \(port)")
            return
        }

        print("🟢 Listening on http://localhost:\(port)/generate")
        print("   Add APPLE_FM_ENDPOINT=http://localhost:\(port)/generate to your .env")

        while true {
            let clientFd = accept(serverSocket, nil, nil)
            guard clientFd >= 0 else { continue }

            Task {
                await handleClient(fd: clientFd)
            }
        }
    }

    static func handleClient(fd: Int32) async {
        // Read request
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0 else {
            close(fd)
            return
        }

        let requestString = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""

        // Only handle POST
        guard requestString.hasPrefix("POST") else {
            let response = "HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 0\r\n\r\n"
            _ = response.withCString { write(fd, $0, strlen($0)) }
            close(fd)
            return
        }

        // Extract JSON body
        guard let bodyStart = requestString.range(of: "\r\n\r\n") else {
            sendError(fd: fd, message: "No body")
            return
        }

        let bodyString = String(requestString[bodyStart.upperBound...])

        // Parse request
        struct FMRequest: Codable {
            let prompt: String
            let max_tokens: Int?
        }

        guard let bodyData = bodyString.data(using: .utf8),
              let request = try? JSONDecoder().decode(FMRequest.self, from: bodyData) else {
            sendError(fd: fd, message: "Invalid JSON")
            return
        }

        // Call Foundation Model
        do {
            let session = LanguageModelSession(instructions: """
            You are a helpful learning assistant for German school students. \
            Respond concisely and helpfully. Follow the user's format instructions exactly.
            """)

            let response = try await session.respond(
                to: request.prompt,
                generating: String.self
            )

            let text = response.content

            // Build JSON response
            struct FMResponse: Codable {
                let text: String
            }

            let responseJSON = try JSONEncoder().encode(FMResponse(text: text))
            let responseBody = String(data: responseJSON, encoding: .utf8) ?? "{}"

            let httpResponse = """
            HTTP/1.1 200 OK\r\n\
            Content-Type: application/json\r\n\
            Content-Length: \(responseBody.utf8.count)\r\n\
            Access-Control-Allow-Origin: *\r\n\
            \r\n\
            \(responseBody)
            """

            _ = httpResponse.withCString { write(fd, $0, strlen($0)) }
        } catch {
            print("⚠️  FM error: \(error)")
            sendError(fd: fd, message: "Foundation Model error: \(error.localizedDescription)")
        }

        close(fd)
    }

    static func sendError(fd: Int32, message: String) {
        struct ErrorResponse: Codable {
            let error: String
        }
        let body = (try? JSONEncoder().encode(ErrorResponse(error: message)))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{\"error\":\"unknown\"}"

        let response = """
        HTTP/1.1 500 Internal Server Error\r\n\
        Content-Type: application/json\r\n\
        Content-Length: \(body.utf8.count)\r\n\
        \r\n\
        \(body)
        """
        _ = response.withCString { write(fd, $0, strlen($0)) }
        close(fd)
    }

    static func createServerSocket(port: UInt16) -> Int32? {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            close(fd)
            return nil
        }

        guard listen(fd, 10) == 0 else {
            close(fd)
            return nil
        }

        return fd
    }
}

if #available(macOS 26.0, *) {
    await FMBridge.main()
} else {
    print("❌ macOS 26.0+ required for Foundation Models")
    exit(1)
}
