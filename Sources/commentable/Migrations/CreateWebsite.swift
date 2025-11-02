import Fluent

struct CreateWebsite: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("websites")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("domain", .string, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("websites").delete()
    }
}
