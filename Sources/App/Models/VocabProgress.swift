import Fluent
import Vapor

final class VocabProgress: Model, Content, @unchecked Sendable {
    static let schema = "vocab_progress"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "player_id")
    var player: Player

    @Parent(key: "vocab_id")
    var vocab: VocabItem

    @Field(key: "box")
    var box: Int

    @Field(key: "ease_factor")
    var easeFactor: Double

    @Field(key: "interval_days")
    var intervalDays: Int

    @Field(key: "next_review")
    var nextReview: Date

    @Field(key: "repetitions")
    var repetitions: Int

    @Field(key: "correct_streak")
    var correctStreak: Int

    init() {}

    init(id: UUID? = nil, playerID: UUID, vocabID: UUID) {
        self.id = id
        self.$player.id = playerID
        self.$vocab.id = vocabID
        self.box = 1
        self.easeFactor = 2.5
        self.intervalDays = 0
        self.nextReview = Date()
        self.repetitions = 0
        self.correctStreak = 0
    }
}
