import Vapor
import Fluent

struct PDFController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let pdf = routes.grouped("api", "pdf")

        // Public: read-only access
        pdf.get("list", use: listPDFs)
        pdf.get("category", ":category", use: listByCategory)
        pdf.get("klasse", ":klasse", use: listByKlasse)
        pdf.get(":pdfID", "info", use: getPDFInfo)
        pdf.get(":pdfID", "download", use: downloadPDF)
        pdf.get("search", use: searchPDFs)
        pdf.get("stats", use: getPDFStats)

        // Protected: admin-only (upload, delete, update)
        let protected = pdf.grouped(AdminAuthMiddleware())
        protected.on(.POST, "upload", body: .collect(maxSize: "50mb"), use: uploadPDF)
        protected.delete(":pdfID", use: deletePDF)
        protected.put(":pdfID", use: updatePDF)
    }

    // MARK: - Upload PDF

    // POST /api/pdf/upload (multipart)
    @Sendable
    func uploadPDF(req: Request) async throws -> PDFDocument {
        let input = try req.content.decode(PDFUploadRequest.self)

        guard let file = input.file else {
            throw Abort(.badRequest, reason: "Keine Datei hochgeladen.")
        }

        // Validate file type
        let ext = (file.filename.split(separator: ".").last.map(String.init) ?? "").lowercased()
        guard ext == "pdf" else {
            throw Abort(.badRequest, reason: "Nur PDF-Dateien sind erlaubt.")
        }

        // Generate unique filename
        let uniqueName = "\(UUID().uuidString)_\(file.filename)"
        let storagePath = req.application.directory.workingDirectory + "Storage/pdfs"

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: storagePath) {
            try FileManager.default.createDirectory(atPath: storagePath, withIntermediateDirectories: true)
        }

        let filePath = storagePath + "/" + uniqueName
        let data = Data(buffer: file.data)

        try data.write(to: URL(fileURLWithPath: filePath))

        let doc = PDFDocument(
            title: input.title,
            filename: uniqueName,
            category: input.category,
            klasse: input.klasse,
            subject: input.subject,
            description: input.description,
            fileSize: data.count,
            uploadedBy: input.uploadedBy ?? "admin"
        )
        try await doc.save(on: req.db)
        return doc
    }

    // MARK: - List PDFs

    // GET /api/pdf/list
    @Sendable
    func listPDFs(req: Request) async throws -> [PDFDocumentResponse] {
        let docs = try await PDFDocument.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .all()

        return docs.map { PDFDocumentResponse(from: $0) }
    }

    // GET /api/pdf/category/:category
    @Sendable
    func listByCategory(req: Request) async throws -> [PDFDocumentResponse] {
        guard let category = req.parameters.get("category") else {
            throw Abort(.badRequest)
        }

        let docs = try await PDFDocument.query(on: req.db)
            .filter(\.$category == category)
            .sort(\.$createdAt, .descending)
            .all()

        return docs.map { PDFDocumentResponse(from: $0) }
    }

    // GET /api/pdf/klasse/:klasse
    @Sendable
    func listByKlasse(req: Request) async throws -> [PDFDocumentResponse] {
        guard let klasse = req.parameters.get("klasse") else {
            throw Abort(.badRequest)
        }

        let docs = try await PDFDocument.query(on: req.db)
            .group(.or) { group in
                group.filter(\.$klasse == klasse)
                group.filter(\.$klasse == nil) // General docs available to all
            }
            .sort(\.$createdAt, .descending)
            .all()

        return docs.map { PDFDocumentResponse(from: $0) }
    }

    // MARK: - Get PDF Info

    // GET /api/pdf/:pdfID/info
    @Sendable
    func getPDFInfo(req: Request) async throws -> PDFDocumentResponse {
        guard let pdfID: UUID = req.parameters.get("pdfID") else {
            throw Abort(.badRequest)
        }

        guard let doc = try await PDFDocument.find(pdfID, on: req.db) else {
            throw Abort(.notFound, reason: "PDF nicht gefunden.")
        }

        return PDFDocumentResponse(from: doc)
    }

    // MARK: - Download PDF

    // GET /api/pdf/:pdfID/download
    @Sendable
    func downloadPDF(req: Request) async throws -> Response {
        guard let pdfID: UUID = req.parameters.get("pdfID") else {
            throw Abort(.badRequest)
        }

        guard let doc = try await PDFDocument.find(pdfID, on: req.db) else {
            throw Abort(.notFound, reason: "PDF nicht gefunden.")
        }

        let storagePath = req.application.directory.workingDirectory + "Storage/pdfs/" + doc.filename

        guard FileManager.default.fileExists(atPath: storagePath) else {
            throw Abort(.notFound, reason: "Datei nicht auf dem Server gefunden.")
        }

        return req.fileio.streamFile(at: storagePath, mediaType: .pdf)
    }

    // MARK: - Delete PDF

    // DELETE /api/pdf/:pdfID
    @Sendable
    func deletePDF(req: Request) async throws -> HTTPStatus {
        guard let pdfID: UUID = req.parameters.get("pdfID") else {
            throw Abort(.badRequest)
        }

        guard let doc = try await PDFDocument.find(pdfID, on: req.db) else {
            throw Abort(.notFound, reason: "PDF nicht gefunden.")
        }

        // Delete file from disk
        let storagePath = req.application.directory.workingDirectory + "Storage/pdfs/" + doc.filename
        try? FileManager.default.removeItem(atPath: storagePath)

        try await doc.delete(on: req.db)
        return .ok
    }

    // MARK: - Update PDF metadata

    // PUT /api/pdf/:pdfID
    @Sendable
    func updatePDF(req: Request) async throws -> PDFDocumentResponse {
        guard let pdfID: UUID = req.parameters.get("pdfID") else {
            throw Abort(.badRequest)
        }

        guard let doc = try await PDFDocument.find(pdfID, on: req.db) else {
            throw Abort(.notFound, reason: "PDF nicht gefunden.")
        }

        let update = try req.content.decode(PDFUpdateRequest.self)

        if let title = update.title { doc.title = title }
        if let category = update.category { doc.category = category }
        if let klasse = update.klasse { doc.klasse = klasse.isEmpty ? nil : klasse }
        if let subject = update.subject { doc.subject = subject.isEmpty ? nil : subject }
        if let description = update.description { doc.description = description.isEmpty ? nil : description }

        try await doc.save(on: req.db)
        return PDFDocumentResponse(from: doc)
    }

    // MARK: - Search PDFs

    // GET /api/pdf/search?q=keyword
    @Sendable
    func searchPDFs(req: Request) async throws -> [PDFDocumentResponse] {
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            throw Abort(.badRequest, reason: "Suchbegriff (q) erforderlich.")
        }

        let q = "%" + query.lowercased() + "%"
        let docs = try await PDFDocument.query(on: req.db)
            .group(.or) { group in
                group.filter(\.$title, .custom("LIKE"), q)
                group.filter(\.$category, .custom("LIKE"), q)
                group.filter(\.$subject, .custom("LIKE"), q)
            }
            .sort(\.$createdAt, .descending)
            .all()

        return docs.map { PDFDocumentResponse(from: $0) }
    }

    // MARK: - Stats

    // GET /api/pdf/stats
    @Sendable
    func getPDFStats(req: Request) async throws -> PDFStatsResponse {
        let total = try await PDFDocument.query(on: req.db).count()
        let byCategory = try await PDFDocument.query(on: req.db).all()

        var categoryCounts: [String: Int] = [:]
        var totalSize = 0
        for doc in byCategory {
            categoryCounts[doc.category, default: 0] += 1
            totalSize += doc.fileSize
        }

        return PDFStatsResponse(
            totalDocuments: total,
            totalSizeBytes: totalSize,
            byCategory: categoryCounts
        )
    }
}
