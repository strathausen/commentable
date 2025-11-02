import NIOSSL
import Fluent
import FluentPostgresDriver
import Leaf
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // Serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Custom error middleware
    app.middleware.use(CustomErrorMiddleware())

    // Session middleware
    app.middleware.use(app.sessions.middleware)

    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "postgres",
        password: Environment.get("DATABASE_PASSWORD") ?? "",
        database: Environment.get("DATABASE_NAME") ?? "commentable",
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)

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
    app.migrations.add(CreateTodo())

    app.views.use(.leaf)

    // register routes
    try routes(app)
}
