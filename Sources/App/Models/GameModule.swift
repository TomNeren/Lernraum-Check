import Fluent
import Vapor

final class GameModule: Model, Content, @unchecked Sendable {
    static let schema = "game_modules"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "type")
    var type: String  // "vocab-quiz", "grammar-drag", "fill-blank"

    @Field(key: "title")
    var title: String

    @OptionalField(key: "kompetenz")
    var kompetenz: String?

    @OptionalField(key: "ls_number")
    var lsNumber: Int?

    @OptionalField(key: "solo_level")
    var soloLevel: String?

    // JSON-Konfiguration — flexibel pro Spieltyp
    @Field(key: "config")
    var config: GameConfig

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Children(for: \.$module)
    var sessions: [GameSession]

    init() {}

    init(id: UUID? = nil, type: String, title: String, kompetenz: String? = nil,
         lsNumber: Int? = nil, soloLevel: String? = nil, config: GameConfig) {
        self.id = id
        self.type = type
        self.title = title
        self.kompetenz = kompetenz
        self.lsNumber = lsNumber
        self.soloLevel = soloLevel
        self.config = config
    }
}

// MARK: - Flexible Game Config

struct GameConfig: Codable {
    var questions: [QuizQuestion]?
    var settings: GameSettings

    init(questions: [QuizQuestion]? = nil, settings: GameSettings = GameSettings()) {
        self.questions = questions
        self.settings = settings
    }
}

struct QuizQuestion: Codable {
    var id: UUID
    var prompt: String          // Die Frage / das Wort
    var correct: String         // Richtige Antwort
    var distractors: [String]   // Falsche Antworten
    var example: String?        // Beispielsatz
    var imageURL: String?       // Optionales Bild
    var timeLimit: Int?         // Sekunden pro Frage

    init(prompt: String, correct: String, distractors: [String],
         example: String? = nil, imageURL: String? = nil, timeLimit: Int? = nil) {
        self.id = UUID()
        self.prompt = prompt
        self.correct = correct
        self.distractors = distractors
        self.example = example
        self.imageURL = imageURL
        self.timeLimit = timeLimit
    }
}

struct GameSettings: Codable {
    var shuffleQuestions: Bool
    var showExamples: Bool
    var pointsPerCorrect: Int
    var bonusForSpeed: Bool
    var timeLimit: Int  // Default-Sekunden pro Frage

    init(shuffleQuestions: Bool = true, showExamples: Bool = true,
         pointsPerCorrect: Int = 10, bonusForSpeed: Bool = true, timeLimit: Int = 15) {
        self.shuffleQuestions = shuffleQuestions
        self.showExamples = showExamples
        self.pointsPerCorrect = pointsPerCorrect
        self.bonusForSpeed = bonusForSpeed
        self.timeLimit = timeLimit
    }
}
