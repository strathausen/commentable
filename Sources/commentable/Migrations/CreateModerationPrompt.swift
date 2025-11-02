import Fluent

struct CreateModerationPrompt: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("moderation_prompts")
            .id()
            .field("website_id", .uuid, .required, .references("websites", "id", onDelete: .cascade))
            .field("prompt", .string, .required)
            .field("is_active", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("moderation_prompts").delete()
    }
}
