import Fluent

struct AddManuallyModeratedToComment: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("comments")
            .field("manually_moderated", .bool, .required, .sql(.default(false)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("comments")
            .deleteField("manually_moderated")
            .update()
    }
}
