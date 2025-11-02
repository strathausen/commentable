import Fluent
import Vapor

func routes(_ app: Application) throws {
    // Redirect root to dashboard (will redirect to login if not authenticated)
    app.get { req async throws -> Response in
        return req.redirect(to: "/dashboard")
    }

    // Register controllers
    try app.register(collection: AuthViewController())
    try app.register(collection: AuthController())
    try app.register(collection: DashboardController())
    try app.register(collection: WebsiteController())
    try app.register(collection: ModerationPromptController())
    try app.register(collection: EmbedController())

    // Keep old todo controller if needed
    try app.register(collection: TodoController())
}
