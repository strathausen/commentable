import NIOSSL
import Fluent
import FluentPostgresDriver
import Leaf
import Vapor
import Foundation

/// Parses a PostgreSQL connection URL in the format:
/// postgresql://username:password@hostname:port/database
private func parseDatabaseURL(_ urlString: String) throws -> SQLPostgresConfiguration {
    guard let url = URL(string: urlString) else {
        throw Abort(.internalServerError, reason: "Invalid DATABASE_URL format")
    }

    guard url.scheme == "postgres" || url.scheme == "postgresql" else {
        throw Abort(.internalServerError, reason: "DATABASE_URL must use postgres:// or postgresql:// scheme")
    }

    let hostname = url.host ?? "localhost"
    let port = url.port ?? SQLPostgresConfiguration.ianaPortNumber
    let username = url.user ?? "postgres"
    let password = url.password ?? ""

    // Database name is the path without the leading slash
    var database = url.path
    if database.hasPrefix("/") {
        database.removeFirst()
    }
    if database.isEmpty {
        database = "commentable"
    }

    return try .init(
        hostname: hostname,
        port: port,
        username: username,
        password: password,
        database: database,
        tls: .prefer(.init(configuration: .clientDefault))
    )
}

// configures your application
public func configure(_ app: Application) async throws {
    // Serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Custom error middleware
    app.middleware.use(CustomErrorMiddleware())

    // Session middleware
    app.middleware.use(app.sessions.middleware)

    // Parse DATABASE_URL or fall back to individual environment variables
    let dbConfig: SQLPostgresConfiguration
    if let databaseURL = Environment.get("DATABASE_URL") {
        dbConfig = try parseDatabaseURL(databaseURL)
    } else {
        dbConfig = .init(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_USERNAME") ?? "postgres",
            password: Environment.get("DATABASE_PASSWORD") ?? "",
            database: Environment.get("DATABASE_NAME") ?? "commentable",
            tls: .prefer(try .init(configuration: .clientDefault))
        )
    }

    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: dbConfig), as: .psql)

    // Register migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateUserSession())
    app.migrations.add(CreateWebsite())
    app.migrations.add(CreatePage())
    app.migrations.add(CreateComment())
    app.migrations.add(CreateModerationPrompt())
    app.migrations.add(AddManuallyModeratedToComment())
    app.migrations.add(RenamePageUrlToPath())
    app.migrations.add(AddArchivedToWebsite())
    app.migrations.add(AddStyleToWebsite())
    app.migrations.add(AddCustomCssToWebsite())
    app.migrations.add(CreateAuditLog())
    app.migrations.add(CreateTodo())

    app.views.use(.leaf)

    // register routes
    try routes(app)
}
