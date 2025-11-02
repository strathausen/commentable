import Fluent
import Vapor

struct ModerationPromptDTO: Content {
    var id: UUID?
    var websiteId: UUID?
    var prompt: String?
    var isActive: Bool?
    var createdAt: Date?
    var updatedAt: Date?
}

struct CreateModerationPromptDTO: Content {
    var prompt: String
    var isActive: Bool?

    func toModel(websiteID: UUID) -> ModerationPrompt {
        ModerationPrompt(websiteID: websiteID, prompt: prompt, isActive: isActive ?? true)
    }
}

struct UpdateModerationPromptDTO: Content {
    var prompt: String?
    var isActive: Bool?
}
