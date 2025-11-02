import Fluent

struct CreatePage: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("pages")
            .id()
            .field("website_id", .uuid, .required, .references("websites", "id", onDelete: .cascade))
            .field("url", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "website_id", "url")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("pages").delete()
    }
}
