import Fluent

struct CreateAuditLog: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("audit_logs")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("action", .string, .required)
            .field("entity_type", .string, .required)
            .field("entity_id", .uuid)
            .field("metadata", .json)
            .field("created_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("audit_logs").delete()
    }
}
