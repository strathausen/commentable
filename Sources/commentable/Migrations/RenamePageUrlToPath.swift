import Fluent
import SQLKit

struct RenamePageUrlToPath: AsyncMigration {
    func prepare(on database: any Database) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }
        try await sql.raw("ALTER TABLE pages RENAME COLUMN url TO path").run()
    }

    func revert(on database: any Database) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }
        try await sql.raw("ALTER TABLE pages RENAME COLUMN path TO url").run()
    }
}
