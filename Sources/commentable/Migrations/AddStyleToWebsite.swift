import Fluent

struct AddStyleToWebsite: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("websites")
            .field("style", .string, .required, .sql(.default("commentable")))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("websites")
            .deleteField("style")
            .update()
    }
}
