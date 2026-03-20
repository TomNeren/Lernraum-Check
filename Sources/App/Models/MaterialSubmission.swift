import Fluent
import Vapor

final class MaterialSubmission: Model, Content, @unchecked Sendable {
    static let schema = "material_submissions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "player_id")
    var player: Player

    @Field(key: "kompetenz_key")
    var kompetenzKey: String  // e.g. "methodenkompetenz-texterschliessung-3"

    @Field(key: "ls_number")
    var lsNumber: Int

    @Field(key: "file_path")
    var filePath: String

    @Field(key: "file_name")
    var fileName: String

    @OptionalField(key: "aufgabenstellung")
    var aufgabenstellung: String?  // text description or second file path

    @OptionalField(key: "feedback_text")
    var feedbackText: String?

    @OptionalField(key: "feedback_inhalt")
    var feedbackInhalt: String?

    @OptionalField(key: "feedback_sprache")
    var feedbackSprache: String?

    @OptionalField(key: "feedback_naechster_schritt")
    var feedbackNaechsterSchritt: String?

    @OptionalField(key: "feedback_fehlermuster")
    var feedbackFehlermuster: String?

    @OptionalField(key: "model_used")
    var modelUsed: String?

    @Field(key: "status")
    var status: String  // "uploaded", "processing", "completed", "error"

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, playerID: UUID, kompetenzKey: String, lsNumber: Int,
         filePath: String, fileName: String, aufgabenstellung: String? = nil) {
        self.id = id
        self.$player.id = playerID
        self.kompetenzKey = kompetenzKey
        self.lsNumber = lsNumber
        self.filePath = filePath
        self.fileName = fileName
        self.aufgabenstellung = aufgabenstellung
        self.status = "uploaded"
    }
}
