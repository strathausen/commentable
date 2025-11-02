import Fluent

struct AddCustomCssToWebsite: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("websites")
            .field("custom_css", .string, .sql(.default("")))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("websites")
            .deleteField("custom_css")
            .update()
    }
}
