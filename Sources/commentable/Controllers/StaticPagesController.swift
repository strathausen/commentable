import Fluent
import Vapor

struct StaticPagesController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // Landing page (public)
        routes.get(use: self.landing)

        // Static pages (public)
        routes.get("about", use: self.about)
        routes.get("roadmap", use: self.roadmap)
        routes.get("imprint", use: self.imprint)
        routes.get("privacy", use: self.privacy)
    }

    @Sendable
    func landing(req: Request) async throws -> View {
        return try await req.view.render("landing")
    }

    @Sendable
    func about(req: Request) async throws -> View {
        struct AboutContext: Encodable {
            let user: UserDTO?
        }

        let user = try? req.auth.require(User.self)
        let context = AboutContext(user: user?.toDTO())
        return try await req.view.render("about", context)
    }

    @Sendable
    func roadmap(req: Request) async throws -> View {
        struct RoadmapContext: Encodable {
            let user: UserDTO?
        }

        let user = try? req.auth.require(User.self)
        let context = RoadmapContext(user: user?.toDTO())
        return try await req.view.render("roadmap", context)
    }

    @Sendable
    func imprint(req: Request) async throws -> View {
        struct ImprintContext: Encodable {
            let user: UserDTO?
        }

        let user = try? req.auth.require(User.self)
        let context = ImprintContext(user: user?.toDTO())
        return try await req.view.render("imprint", context)
    }

    @Sendable
    func privacy(req: Request) async throws -> View {
        struct PrivacyContext: Encodable {
            let user: UserDTO?
        }

        let user = try? req.auth.require(User.self)
        let context = PrivacyContext(user: user?.toDTO())
        return try await req.view.render("privacy", context)
    }
}
