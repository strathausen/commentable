import Fluent
import Vapor
import struct Foundation.UUID

final class ModerationPrompt: Model, @unchecked Sendable {
    static let schema = "moderation_prompts"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "website_id")
    var website: Website

    @Field(key: "prompt")
    var prompt: String

    @Field(key: "is_active")
    var isActive: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(id: UUID? = nil, websiteID: UUID, prompt: String, isActive: Bool = true) {
        self.id = id
        self.$website.id = websiteID
        self.prompt = prompt
        self.isActive = isActive
    }

    func toDTO() -> ModerationPromptDTO {
        .init(
            id: self.id,
            websiteId: self.$website.id,
            prompt: self.$prompt.value,
            isActive: self.$isActive.value,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
}
