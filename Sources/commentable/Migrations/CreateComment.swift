import Fluent

struct CreateComment: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("comments")
            .id()
            .field("page_id", .uuid, .required, .references("pages", "id", onDelete: .cascade))
            .field("author_name", .string)
            .field("content", .string, .required)
            .field("status", .string, .required)
            .field("moderation_result", .string)
            .field("created_at", .datetime)
            .field("moderated_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("comments").delete()
    }
}
