import Vapor

/// Shared AI service with multi-provider fallback chain:
/// 1. Claude API (supports files via vision/document)
/// 2. Gemini API (supports files via inline_data)
/// 3. Apple Foundation Model (on-device, text only)
/// 4. Local fallback
struct ClaudeService {

    struct AIResult {
        let text: String
        let model: String
    }

    /// File attachment for vision/document API calls
    struct FileAttachment {
        let data: Data        // raw file bytes
        let mediaType: String // e.g. "application/pdf", "image/jpeg"
        let fileName: String
    }

    // MARK: - Text-only call (existing interface)

    static func callAI(prompt: String, req: Request, maxTokens: Int = 500, task: String = "general") async throws -> AIResult {
        return try await callAI(prompt: prompt, systemPrompt: nil, file: nil, req: req, maxTokens: maxTokens, task: task)
    }

    // MARK: - Full call with optional system prompt + file

    static func callAI(
        prompt: String,
        systemPrompt: String? = nil,
        file: FileAttachment? = nil,
        req: Request,
        maxTokens: Int = 500,
        task: String = "general"
    ) async throws -> AIResult {

        // Skip Apple FM for file-based requests (no vision support)
        if file == nil {
            if let result = try? await callAppleFoundationModel(prompt: prompt, req: req) {
                return result
            }
        }

        // Check for task-specific model override
        let taskModelKey = "AI_MODEL_\(task.uppercased())"
        let taskModel = Environment.get(taskModelKey)

        // Try Claude API (supports PDF + images natively)
        let claudeKey = Environment.get("CLAUDE_API_KEY") ?? ""
        if !claudeKey.isEmpty {
            let model = taskModel ?? Environment.get("CLAUDE_MODEL") ?? "claude-haiku-4-5-20251001"
            if model.hasPrefix("claude") || taskModel == nil {
                let claudeModel = model.hasPrefix("claude") ? model : "claude-haiku-4-5-20251001"
                if let result = try? await callClaudeWithFile(
                    prompt: prompt, systemPrompt: systemPrompt, file: file,
                    req: req, apiKey: claudeKey, model: claudeModel, maxTokens: maxTokens
                ) {
                    return result
                }
            }
        }

        // Try Gemini API (supports PDF + images natively)
        let geminiKey = Environment.get("GEMINI_API_KEY") ?? Environment.get("GOOGLE_API_KEY") ?? ""
        if !geminiKey.isEmpty {
            let model = taskModel?.hasPrefix("gemini") == true ? taskModel! : Environment.get("GEMINI_MODEL") ?? "gemini-2.0-flash"
            if let result = try? await callGeminiWithFile(
                prompt: prompt, systemPrompt: systemPrompt, file: file,
                req: req, apiKey: geminiKey, model: model, maxTokens: maxTokens
            ) {
                return result
            }
        }

        // Local fallback
        return AIResult(
            text: generateFallback(prompt: prompt),
            model: "fallback-local"
        )
    }

    // MARK: - Claude API (with file + system prompt support)

    private static func callClaudeWithFile(
        prompt: String,
        systemPrompt: String?,
        file: FileAttachment?,
        req: Request,
        apiKey: String,
        model: String,
        maxTokens: Int
    ) async throws -> AIResult? {

        // Build content blocks for the user message
        var contentBlocks: [[String: Any]] = []

        // Add file as document/image content block
        if let file = file {
            if file.mediaType == "application/pdf" {
                // Claude PDF support: type "document" with base64 source
                contentBlocks.append([
                    "type": "document",
                    "source": [
                        "type": "base64",
                        "media_type": "application/pdf",
                        "data": file.data.base64EncodedString()
                    ] as [String: String]
                ])
            } else {
                // Image support: type "image" with base64 source
                contentBlocks.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": file.mediaType,
                        "data": file.data.base64EncodedString()
                    ] as [String: String]
                ])
            }
        }

        // Add text content block
        contentBlocks.append([
            "type": "text",
            "text": prompt
        ])

        // Build request body as dictionary (for flexible JSON structure)
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                [
                    "role": "user",
                    "content": contentBlocks
                ] as [String: Any]
            ]
        ]

        // Add system prompt if provided
        if let sys = systemPrompt, !sys.isEmpty {
            body["system"] = sys
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var headers = HTTPHeaders()
        headers.add(name: "x-api-key", value: apiKey)
        headers.add(name: "anthropic-version", value: "2023-06-01")
        headers.add(name: "content-type", value: "application/json")

        let response = try await req.client.post(URI(string: "https://api.anthropic.com/v1/messages"), headers: headers) { clientReq in
            clientReq.body = .init(data: jsonData)
        }

        guard response.status == .ok else {
            let errorBody = response.body.map { String(buffer: $0) } ?? "Unknown error"
            req.logger.error("Claude API error: \(response.status) - \(errorBody)")
            return nil
        }

        struct ClaudeResponse: Decodable {
            let content: [ClaudeContentBlock]
        }
        struct ClaudeContentBlock: Decodable {
            let type: String
            let text: String?
        }

        let claudeResponse = try response.content.decode(ClaudeResponse.self)
        let text = claudeResponse.content.compactMap(\.text).joined(separator: "\n")
        return AIResult(text: text, model: model)
    }

    // MARK: - Gemini API (with file + system prompt support)

    private static func callGeminiWithFile(
        prompt: String,
        systemPrompt: String?,
        file: FileAttachment?,
        req: Request,
        apiKey: String,
        model: String,
        maxTokens: Int
    ) async throws -> AIResult? {

        // Build parts array
        var parts: [[String: Any]] = []

        // Add file as inline_data part
        if let file = file {
            parts.append([
                "inline_data": [
                    "mime_type": file.mediaType,
                    "data": file.data.base64EncodedString()
                ] as [String: String]
            ])
        }

        // Add text part
        parts.append(["text": prompt])

        var body: [String: Any] = [
            "contents": [
                ["parts": parts]
            ],
            "generationConfig": [
                "maxOutputTokens": maxTokens
            ] as [String: Any]
        ]

        // Add system instruction if provided
        if let sys = systemPrompt, !sys.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": sys]]
            ] as [String: Any]
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        let apiURL = URI(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")

        let response = try await req.client.post(apiURL) { clientReq in
            clientReq.headers.add(name: "content-type", value: "application/json")
            clientReq.body = .init(data: jsonData)
        }

        guard response.status == .ok else {
            let errorBody = response.body.map { String(buffer: $0) } ?? "Unknown error"
            req.logger.error("Gemini API error: \(response.status) - \(errorBody)")
            return nil
        }

        struct GeminiResponse: Decodable {
            let candidates: [GeminiCandidate]?
        }
        struct GeminiCandidate: Decodable {
            let content: GeminiResponseContent?
        }
        struct GeminiResponseContent: Decodable {
            let parts: [GeminiPart]?
        }
        struct GeminiPart: Decodable {
            let text: String?
        }

        let geminiResponse = try response.content.decode(GeminiResponse.self)
        let text = geminiResponse.candidates?.first?.content?.parts?.compactMap(\.text).joined(separator: "\n") ?? ""

        guard !text.isEmpty else { return nil }
        return AIResult(text: text, model: model)
    }

    // MARK: - Apple Foundation Model (text-only)

    private static func callAppleFoundationModel(prompt: String, req: Request) async throws -> AIResult? {
        guard let fmEndpoint = Environment.get("APPLE_FM_ENDPOINT") else {
            return nil
        }

        struct FMRequest: Content {
            let prompt: String
            let max_tokens: Int
        }
        struct FMResponse: Content {
            let text: String
        }

        let response = try await req.client.post(URI(string: fmEndpoint)) { clientReq in
            try clientReq.content.encode(FMRequest(prompt: prompt, max_tokens: 500))
        }

        guard response.status == .ok else {
            req.logger.info("Apple FM not available, falling back")
            return nil
        }

        let fmResponse = try response.content.decode(FMResponse.self)
        return AIResult(text: fmResponse.text, model: "apple-foundation-model")
    }

    // MARK: - Fallback

    private static func generateFallback(prompt: String) -> String {
        if prompt.contains("Vokabel") || prompt.contains("vocab") {
            return """
            Gut gemacht beim Vokabellernen! \
            Versuche, die schwierigen Wörter in eigenen Sätzen zu verwenden. \
            Wiederhole sie morgen noch einmal. Weiter so!
            """
        }
        return """
        Toll, dass du übst! \
        Versuche das Thema in kleinen Schritten zu üben. \
        Viel Erfolg beim Lernen!
        """
    }
}
