import Fluent
import Vapor

final class PDFDocument: Model, Content, @unchecked Sendable {
    static let schema = "pdf_documents"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "filename")
    var filename: String

    @Field(key: "category")
    var category: String  // "arbeitsblatt", "loesung", "material", "test"

    @OptionalField(key: "klasse")
    var klasse: String?

    @OptionalField(key: "subject")
    var subject: String?

    @OptionalField(key: "description")
    var description: String?

    @Field(key: "file_size")
    var fileSize: Int

    @Field(key: "uploaded_by")
    var uploadedBy: String  // "admin" or teacher name

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, title: String, filename: String, category: String,
         klasse: String? = nil, subject: String? = nil, description: String? = nil,
         fileSize: Int, uploadedBy: String) {
        self.id = id
        self.title = title
        self.filename = filename
        self.category = category
        self.klasse = klasse
        self.subject = subject
        self.description = description
        self.fileSize = fileSize
        self.uploadedBy = uploadedBy
    }
}
