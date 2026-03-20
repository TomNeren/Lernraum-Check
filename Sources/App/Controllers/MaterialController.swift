import Vapor
import Fluent

struct MaterialController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let mat = routes.grouped("api", "materials")

        // Upload student submission
        mat.on(.POST, "upload", body: .collect(maxSize: "50mb"), use: uploadSubmission)

        // Get submissions for a player + kompetenz
        mat.get("submissions", ":playerID", use: getSubmissions)

        // Get feedback for a specific submission
        mat.get(":key", "feedback", use: getFeedback)

        // Download material PDF (placeholder — serves from Storage/materials/)
        mat.get(":key", "download", use: downloadMaterial)

        // Admin: system prompt management
        let prompt = routes.grouped("api", "system-prompt")
        prompt.get(use: getSystemPrompt)
        prompt.put(use: updateSystemPrompt)

        // Admin: list all submissions
        mat.get("admin", "submissions", use: adminListSubmissions)

        // Admin: upload material PDF for a competency+LS
        mat.on(.POST, "admin", "upload-material", body: .collect(maxSize: "50mb"), use: adminUploadMaterial)

        // Admin: list existing material PDFs
        mat.get("admin", "list-materials", use: adminListMaterials)
    }

    // MARK: - Upload Submission

    @Sendable
    func uploadSubmission(req: Request) async throws -> MaterialSubmissionResponse {
        let upload = try req.content.decode(MaterialUploadRequest.self)

        guard let player = try await Player.find(upload.playerId, on: req.db) else {
            throw Abort(.notFound, reason: "Spieler nicht gefunden.")
        }

        // Validate file
        guard let file = upload.file else {
            throw Abort(.badRequest, reason: "Keine Datei hochgeladen.")
        }

        // Save file to Storage/submissions/
        let storagePath = req.application.directory.workingDirectory + "Storage/submissions"
        if !FileManager.default.fileExists(atPath: storagePath) {
            try FileManager.default.createDirectory(atPath: storagePath, withIntermediateDirectories: true)
        }

        let fileID = UUID().uuidString
        let fileName = file.filename.isEmpty ? "\(fileID).pdf" : file.filename
        let filePath = storagePath + "/\(fileID)_\(fileName)"

        try await req.fileio.writeFile(file.data, at: filePath)

        // Save submission record
        let submission = MaterialSubmission(
            playerID: player.id!,
            kompetenzKey: upload.kompetenzKey,
            lsNumber: upload.lsNumber ?? 0,
            filePath: filePath,
            fileName: fileName,
            aufgabenstellung: upload.aufgabenstellung
        )
        try await submission.save(on: req.db)

        // If aufgabenstellung is provided, generate feedback async
        if let aufgabe = upload.aufgabenstellung, !aufgabe.isEmpty {
            submission.status = "processing"
            try await submission.update(on: req.db)

            // Generate feedback
            do {
                let feedback = try await generateMaterialFeedback(
                    submission: submission,
                    aufgabenstellung: aufgabe,
                    playerName: player.name,
                    klasse: player.klasse,
                    req: req
                )
                submission.feedbackText = feedback.full
                submission.feedbackInhalt = feedback.inhalt
                submission.feedbackSprache = feedback.sprache
                submission.feedbackNaechsterSchritt = feedback.naechsterSchritt
                submission.feedbackFehlermuster = feedback.fehlermuster
                submission.modelUsed = feedback.model
                submission.status = "completed"
                try await submission.update(on: req.db)
            } catch {
                submission.status = "error"
                submission.feedbackText = "Fehler bei der Feedback-Generierung: \(error.localizedDescription)"
                try await submission.update(on: req.db)
            }
        }

        return MaterialSubmissionResponse(
            id: submission.id!,
            status: submission.status,
            feedback: submission.feedbackText != nil ? MaterialFeedbackData(
                inhalt: submission.feedbackInhalt ?? "",
                sprache: submission.feedbackSprache ?? "",
                naechsterSchritt: submission.feedbackNaechsterSchritt ?? "",
                full: submission.feedbackText ?? ""
            ) : nil
        )
    }

    // MARK: - Generate Feedback

    private func generateMaterialFeedback(
        submission: MaterialSubmission,
        aufgabenstellung: String,
        playerName: String,
        klasse: String,
        req: Request
    ) async throws -> (inhalt: String, sprache: String, naechsterSchritt: String, fehlermuster: String, full: String, model: String) {

        // Load system prompt from DB
        let systemPrompt = try await SystemPrompt.query(on: req.db)
            .filter(\.$key == "material_feedback")
            .first()

        let systemText = systemPrompt?.promptText ?? "Du bist ein Englischlehrer. Gib Feedback auf die Schülerarbeit."

        // Read the uploaded file from disk
        let fileData = try Data(contentsOf: URL(fileURLWithPath: submission.filePath))

        // Determine media type from file extension
        let mediaType: String
        let lowerName = submission.fileName.lowercased()
        if lowerName.hasSuffix(".pdf") {
            mediaType = "application/pdf"
        } else if lowerName.hasSuffix(".jpg") || lowerName.hasSuffix(".jpeg") {
            mediaType = "image/jpeg"
        } else if lowerName.hasSuffix(".png") {
            mediaType = "image/png"
        } else if lowerName.hasSuffix(".heic") {
            mediaType = "image/heic"
        } else {
            mediaType = "application/pdf"
        }

        let fileAttachment = ClaudeService.FileAttachment(
            data: fileData,
            mediaType: mediaType,
            fileName: submission.fileName
        )

        let userPrompt = """
        Schüler: \(playerName) (Klasse: \(klasse))
        Kompetenzbereich: \(submission.kompetenzKey)
        Lernfortschritt: \(submission.lsNumber)

        --- AUFGABENSTELLUNG ---
        \(aufgabenstellung)

        --- SCHÜLERANTWORT ---
        Die Schülerantwort ist als Datei angehängt (\(submission.fileName)). \
        Bitte lies und analysiere den vollständigen Inhalt der Datei.

        Bitte gib dein Feedback gemäß der vorgegebenen Struktur.
        """

        let result = try await ClaudeService.callAI(
            prompt: userPrompt,
            systemPrompt: systemText,
            file: fileAttachment,
            req: req,
            maxTokens: 1500,
            task: "material_feedback"
        )

        // Parse sections from response
        let inhalt = extractSection(from: result.text, marker: "--- INHALT ---", endMarker: "--- SPRACHE ---")
        let sprache = extractSection(from: result.text, marker: "--- SPRACHE ---", endMarker: "--- NÄCHSTER SCHRITT ---")
        let naechsterSchritt = extractSection(from: result.text, marker: "--- NÄCHSTER SCHRITT ---", endMarker: "--- FEHLERMUSTER (LEHRKRAFT) ---")
        let fehlermuster = extractSection(from: result.text, marker: "--- FEHLERMUSTER (LEHRKRAFT) ---", endMarker: nil)

        return (inhalt: inhalt, sprache: sprache, naechsterSchritt: naechsterSchritt, fehlermuster: fehlermuster, full: result.text, model: result.model)
    }

    private func extractSection(from text: String, marker: String, endMarker: String?) -> String {
        guard let startRange = text.range(of: marker) else {
            return text
        }
        let afterStart = text[startRange.upperBound...]
        if let end = endMarker, let endRange = afterStart.range(of: end) {
            return String(afterStart[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(afterStart).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Get Feedback

    @Sendable
    func getFeedback(req: Request) async throws -> MaterialFeedbackResponse {
        guard let key = req.parameters.get("key"),
              let playerIdStr = req.query[String.self, at: "playerId"],
              let playerId = UUID(uuidString: playerIdStr) else {
            throw Abort(.badRequest)
        }

        let submission = try await MaterialSubmission.query(on: req.db)
            .filter(\.$kompetenzKey == key)
            .filter(\.$player.$id == playerId)
            .sort(\.$createdAt, .descending)
            .first()

        guard let sub = submission else {
            throw Abort(.notFound, reason: "Keine Abgabe gefunden.")
        }

        return MaterialFeedbackResponse(
            id: sub.id!,
            status: sub.status,
            inhalt: sub.feedbackInhalt,
            sprache: sub.feedbackSprache,
            naechsterSchritt: sub.feedbackNaechsterSchritt,
            fehlermuster: sub.feedbackFehlermuster,
            text: sub.feedbackText,
            createdAt: sub.createdAt ?? Date()
        )
    }

    // MARK: - Get Submissions

    @Sendable
    func getSubmissions(req: Request) async throws -> [MaterialSubmissionListItem] {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        let submissions = try await MaterialSubmission.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .sort(\.$createdAt, .descending)
            .all()

        return submissions.map { sub in
            MaterialSubmissionListItem(
                id: sub.id!,
                kompetenzKey: sub.kompetenzKey,
                lsNumber: sub.lsNumber,
                fileName: sub.fileName,
                status: sub.status,
                hasFeedback: sub.feedbackText != nil,
                createdAt: sub.createdAt ?? Date()
            )
        }
    }

    // MARK: - Download Material

    @Sendable
    func downloadMaterial(req: Request) async throws -> Response {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest)
        }

        // Look for PDF in Storage/materials/ by key
        let materialsPath = req.application.directory.workingDirectory + "Storage/materials"
        let filePath = materialsPath + "/\(key).pdf"

        guard FileManager.default.fileExists(atPath: filePath) else {
            throw Abort(.notFound, reason: "Material noch nicht hinterlegt. Bitte wende dich an die Lehrkraft.")
        }

        return try await req.fileio.asyncStreamFile(at: filePath)
    }

    // MARK: - System Prompt

    @Sendable
    func getSystemPrompt(req: Request) async throws -> SystemPromptResponse {
        let prompt = try await SystemPrompt.query(on: req.db)
            .filter(\.$key == "material_feedback")
            .first()

        return SystemPromptResponse(
            key: "material_feedback",
            promptText: prompt?.promptText ?? "",
            updatedAt: prompt?.updatedAt
        )
    }

    @Sendable
    func updateSystemPrompt(req: Request) async throws -> SystemPromptResponse {
        let input = try req.content.decode(SystemPromptUpdateRequest.self)

        let existing = try await SystemPrompt.query(on: req.db)
            .filter(\.$key == "material_feedback")
            .first()

        if let prompt = existing {
            prompt.promptText = input.promptText
            try await prompt.update(on: req.db)
            return SystemPromptResponse(key: "material_feedback", promptText: prompt.promptText, updatedAt: prompt.updatedAt)
        } else {
            let prompt = SystemPrompt(key: "material_feedback", promptText: input.promptText)
            try await prompt.save(on: req.db)
            return SystemPromptResponse(key: "material_feedback", promptText: prompt.promptText, updatedAt: prompt.updatedAt)
        }
    }

    // MARK: - Admin

    @Sendable
    func adminListSubmissions(req: Request) async throws -> [AdminSubmissionItem] {
        let submissions = try await MaterialSubmission.query(on: req.db)
            .with(\.$player)
            .sort(\.$createdAt, .descending)
            .range(..<100)
            .all()

        return submissions.map { sub in
            AdminSubmissionItem(
                id: sub.id!,
                playerName: sub.player.name,
                klasse: sub.player.klasse,
                kompetenzKey: sub.kompetenzKey,
                lsNumber: sub.lsNumber,
                fileName: sub.fileName,
                status: sub.status,
                hasFeedback: sub.feedbackText != nil,
                createdAt: sub.createdAt ?? Date()
            )
        }
    }
    // MARK: - Admin: Upload Material PDF

    @Sendable
    func adminUploadMaterial(req: Request) async throws -> HTTPStatus {
        struct MaterialFileUpload: Content {
            var key: String
            var file: File
        }

        let upload = try req.content.decode(MaterialFileUpload.self)

        // Ensure Storage/materials/ directory exists
        let materialsPath = req.application.directory.workingDirectory + "Storage/materials"
        if !FileManager.default.fileExists(atPath: materialsPath) {
            try FileManager.default.createDirectory(atPath: materialsPath, withIntermediateDirectories: true)
        }

        // Save as {key}.pdf
        let filePath = materialsPath + "/\(upload.key).pdf"
        try await req.fileio.writeFile(upload.file.data, at: filePath)

        return .ok
    }

    // MARK: - Admin: List Material PDFs

    @Sendable
    func adminListMaterials(req: Request) async throws -> [MaterialFileInfo] {
        let materialsPath = req.application.directory.workingDirectory + "Storage/materials"

        guard FileManager.default.fileExists(atPath: materialsPath) else {
            return []
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: materialsPath)
            .filter { $0.hasSuffix(".pdf") }
            .sorted()

        return files.map { fileName in
            let fullPath = materialsPath + "/\(fileName)"
            let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath)
            let sizeBytes = (attrs?[.size] as? Int) ?? 0
            let sizeLabel = sizeBytes > 1_048_576
                ? String(format: "%.1f MB", Double(sizeBytes) / 1_048_576)
                : "\(sizeBytes / 1024) KB"
            let key = String(fileName.dropLast(4)) // remove .pdf
            return MaterialFileInfo(key: key, fileName: fileName, size: sizeLabel)
        }
    }
}

struct MaterialFileInfo: Content {
    var key: String
    var fileName: String
    var size: String
}

// MARK: - DTOs

struct MaterialUploadRequest: Content {
    var playerId: UUID
    var kompetenzKey: String
    var lsNumber: Int?
    var aufgabenstellung: String?
    var file: File?
}

struct MaterialSubmissionResponse: Content {
    var id: UUID
    var status: String
    var feedback: MaterialFeedbackData?
}

struct MaterialFeedbackData: Content {
    var inhalt: String
    var sprache: String
    var naechsterSchritt: String
    var full: String
}

struct MaterialFeedbackResponse: Content {
    var id: UUID
    var status: String
    var inhalt: String?
    var sprache: String?
    var naechsterSchritt: String?
    var fehlermuster: String?
    var text: String?
    var createdAt: Date
}

struct MaterialSubmissionListItem: Content {
    var id: UUID
    var kompetenzKey: String
    var lsNumber: Int
    var fileName: String
    var status: String
    var hasFeedback: Bool
    var createdAt: Date
}

struct SystemPromptResponse: Content {
    var key: String
    var promptText: String
    var updatedAt: Date?
}

struct SystemPromptUpdateRequest: Content {
    var promptText: String
}

struct AdminSubmissionItem: Content {
    var id: UUID
    var playerName: String
    var klasse: String
    var kompetenzKey: String
    var lsNumber: Int
    var fileName: String
    var status: String
    var hasFeedback: Bool
    var createdAt: Date
}
