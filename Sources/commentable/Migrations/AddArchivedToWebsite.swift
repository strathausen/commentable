import Fluent

struct AddArchivedToWebsite: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("websites")
            .field("archived", .bool, .required, .sql(.default(false)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("websites")
            .deleteField("archived")
            .update()
    }
}
