import Fluent

struct CreateUserSession: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("user_sessions")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("token", .string, .required)
            .field("created_at", .datetime)
            .field("expires_at", .datetime)
            .unique(on: "token")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("user_sessions").delete()
    }
}
