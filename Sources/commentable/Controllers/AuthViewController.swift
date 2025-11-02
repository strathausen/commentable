import Fluent
import Vapor

struct AuthViewController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("login", use: self.loginPage)
        routes.get("register", use: self.registerPage)
    }

    @Sendable
    func loginPage(req: Request) async throws -> View {
        return try await req.view.render("login")
    }

    @Sendable
    func registerPage(req: Request) async throws -> View {
        return try await req.view.render("register")
    }
}
