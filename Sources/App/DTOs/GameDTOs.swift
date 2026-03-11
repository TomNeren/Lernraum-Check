import Vapor

// MARK: - Player DTOs

struct LoginRequest: Content {
    var name: String
    var klasse: String
}

struct PlayerStats: Content {
    var player: Player
    var totalGames: Int
    var totalScore: Int
    var averagePercent: Double
    var recentSessions: [GameSession]
}

// MARK: - Game DTOs

struct GameListItem: Content {
    var id: UUID
    var type: String
    var title: String
    var kompetenz: String?
    var lsNumber: Int?
    var soloLevel: String?
    var questionCount: Int
}

struct CreateGameRequest: Content {
    var type: String
    var title: String
    var kompetenz: String?
    var lsNumber: Int?
    var soloLevel: String?
    var config: GameConfig
}

// MARK: - Session DTOs

struct SubmitScoreRequest: Content {
    var playerID: UUID
    var moduleID: UUID
    var score: Int
    var maxScore: Int
    var timeSpent: Int
    var details: SessionDetails?
}

struct LeaderboardEntry: Content {
    var rank: Int
    var playerName: String
    var klasse: String
    var score: Int
    var maxScore: Int
    var percent: Double
    var timeSpent: Int
}

// MARK: - Lernraum DTOs

struct CheckinRequest: Content {
    var playerID: UUID
    var raum: String
}

struct CheckoutRequest: Content {
    var playerID: UUID
}

struct AktivCheckin: Content {
    var id: UUID
    var playerName: String
    var klasse: String
    var raum: String
    var checkedInAt: Date
}

// MARK: - Vocab DTOs

struct VocabImportRequest: Content {
    var topic: String?
    var items: [VocabImportItem]
}

struct VocabImportItem: Content {
    var english: String
    var german: String
    var example: String?
}

struct VocabReviewRequest: Content {
    var playerID: UUID
    var vocabID: UUID
    var quality: Int  // 0-3
}

struct VocabDueCard: Content {
    var vocabID: UUID
    var english: String
    var german: String
    var exampleSentence: String?
    var box: Int
    var topic: String?
}

struct VocabStats: Content {
    var box1: Int
    var box2: Int
    var box3: Int
    var box4: Int
    var box5: Int
    var total: Int
    var dueToday: Int
}

// MARK: - Personal Task DTOs

struct AssignTaskRequest: Content {
    var playerID: UUID
    var title: String
    var type: String
    var config: GameConfig
    var dueDate: Date?
    var note: String?
}

struct PersonalTaskResponse: Content {
    var id: UUID
    var title: String
    var type: String
    var config: GameConfig
    var assignedAt: Date?
    var dueDate: Date?
    var note: String?
    var completed: Bool
}

// MARK: - Admin DTOs

struct AdminLoginRequest: Content {
    var password: String
}

struct AdminLoginResponse: Content {
    var token: String
    var message: String
}

struct AdminOverview: Content {
    var totalStudents: Int
    var totalGames: Int
    var totalSessions: Int
    var totalVocabItems: Int
    var klassen: [String]
    var activeCheckins: [AktivCheckin]
}

struct StudentOverview: Content {
    var id: UUID
    var name: String
    var klasse: String
    var currentRaum: String?
    var totalGames: Int
    var totalScore: Int
    var averagePercent: Double
    var lastSeen: Date
    var recentGames: [CompletedGame]
}

struct StudentDetail: Content {
    var id: UUID
    var name: String
    var klasse: String
    var currentRaum: String?
    var lastSeen: Date
    var totalGames: Int
    var totalScore: Int
    var averagePercent: Double
    var vocabTotal: Int
    var vocabBoxes: [Int]
    var vocabDueToday: Int
    var openTasks: Int
    var completedTasks: Int
    var games: [CompletedGame]
}

struct CompletedGame: Content {
    var gameTitle: String
    var gameType: String
    var score: Int
    var maxScore: Int
    var percent: Double
    var completedAt: Date?
}

// MARK: - Teacher Dashboard DTOs

struct ForceCheckoutAllResponse: Content {
    var checkedOut: Int
}

// MARK: - Klasse / Lesson Code DTOs

struct CreateKlasseRequest: Content {
    var name: String
}

struct AddStudentsRequest: Content {
    var names: [String]
}

struct AddStudentsResponse: Content {
    var created: Int
    var existing: Int
}

struct StartLessonRequest: Content {
    var durationMinutes: Int?
}

struct LessonCodeResponse: Content {
    var id: UUID
    var code: String
    var klasse: String
    var klasseID: UUID
    var expiresAt: Date
    var joinURL: String
}

struct JoinCodeInfoResponse: Content {
    var klasse: String
    var students: [StudentNameEntry]
}

struct StudentNameEntry: Content {
    var id: UUID
    var name: String
}

struct CodeCheckinRequest: Content {
    var playerID: UUID
}

struct CodeCheckinResponse: Content {
    var id: UUID
    var name: String
    var klasse: String
    var message: String
}

struct KlasseDetailResponse: Content {
    var id: UUID
    var name: String
    var studentCount: Int
    var students: [StudentNameEntry]
    var activeCode: LessonCodeResponse?
}

// MARK: - Content Assignment DTOs

struct AssignContentRequest: Content {
    var contentType: String   // "vocab-topic" or "game"
    var contentValue: String  // topic name or game UUID
    var klasse: String?       // assign to class
    var playerID: UUID?       // assign to individual
}

struct VocabItemResponse: Content {
    var id: UUID
    var english: String
    var german: String
    var exampleSentence: String?
    var topic: String?
    var difficulty: Int
}

struct VocabItemUpdateRequest: Content {
    var english: String?
    var german: String?
    var exampleSentence: String?
    var topic: String?
    var difficulty: Int?
}

struct TopicDetail: Content {
    var topic: String
    var itemCount: Int
    var assignedTo: [String]  // klasse names
}

struct GameAssignmentInfo: Content {
    var game: GameListItem
    var assignedTo: [String]  // klasse names
}

struct KlasseListItem: Content {
    var id: UUID
    var name: String
    var studentCount: Int
    var hasActiveCode: Bool
}

struct KlasseOverview: Content {
    var klasse: String
    var playerCount: Int
    var averageScore: Double
    var gamesPlayed: Int
}

// MARK: - Chat DTOs

struct SendChatRequest: Content {
    var playerID: UUID
    var message: String
}

struct ChatMessageResponse: Content {
    var id: UUID
    var playerName: String
    var klasse: String
    var message: String
    var createdAt: Date
    var readAt: Date?
}

struct UnreadCountResponse: Content {
    var count: Int
}

// MARK: - PDF DTOs

struct PDFUploadRequest: Content {
    var title: String
    var category: String
    var klasse: String?
    var subject: String?
    var description: String?
    var uploadedBy: String?
    var file: File?
}

struct PDFUpdateRequest: Content {
    var title: String?
    var category: String?
    var klasse: String?
    var subject: String?
    var description: String?
}

struct PDFDocumentResponse: Content {
    var id: UUID
    var title: String
    var category: String
    var klasse: String?
    var subject: String?
    var description: String?
    var fileSize: Int
    var uploadedBy: String
    var createdAt: Date
    var downloadURL: String

    init(from doc: PDFDocument) {
        self.id = doc.id!
        self.title = doc.title
        self.category = doc.category
        self.klasse = doc.klasse
        self.subject = doc.subject
        self.description = doc.description
        self.fileSize = doc.fileSize
        self.uploadedBy = doc.uploadedBy
        self.createdAt = doc.createdAt ?? Date()
        self.downloadURL = "/api/pdf/\(doc.id!)/download"
    }
}

struct PDFStatsResponse: Content {
    var totalDocuments: Int
    var totalSizeBytes: Int
    var byCategory: [String: Int]
}

// MARK: - AI Feedback DTOs

struct GameFeedbackRequest: Content {
    var playerID: UUID
    var sessionID: UUID
}

struct VocabFeedbackRequest: Content {
    var playerID: UUID
    var difficultWords: [DifficultWord]
    var totalReviewed: Int
    var correctCount: Int
}

struct DifficultWord: Content {
    var english: String
    var german: String
    var example: String?
}

struct GeneralFeedbackRequest: Content {
    var playerID: UUID
    var question: String
    var context: String?
}

struct AIFeedbackResponse: Content {
    var id: UUID
    var feedbackType: String
    var text: String
    var tips: [String]
    var createdAt: Date
}

struct AIFeedbackListItem: Content {
    var id: UUID
    var playerName: String
    var klasse: String
    var feedbackType: String
    var preview: String
    var modelUsed: String
    var createdAt: Date
}

struct AIFeedbackStats: Content {
    var totalFeedbacks: Int
    var byType: [String: Int]
}

struct AIConfigResponse: Content {
    var isConfigured: Bool
    var model: String
    var maxTokens: Int
}

struct AIConfigTestResult: Content {
    var success: Bool
    var message: String
}
