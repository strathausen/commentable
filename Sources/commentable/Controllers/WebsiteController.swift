import Fluent
import Vapor

struct WebsiteController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let websites = routes.grouped("websites")
        let protected = websites.grouped(User.sessionAuthenticator(), RedirectMiddleware())

        protected.get(use: self.index)
        protected.post(use: self.create)
        protected.group(":websiteID") { website in
            website.get(use: self.show)
            website.delete(use: self.delete)
            website.get("pages", use: self.pages)
            website.get("comments", use: self.comments)
        }
    }

    @Sendable
    func index(req: Request) async throws -> [WebsiteWithStatsDTO] {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        let websites = try await Website.query(on: req.db)
            .filter(\.$user.$id == userID)
            .with(\.$pages) { page in
                page.with(\.$comments)
            }
            .all()

        return websites.map { website in
            let pageCount = website.pages.count
            let commentCount = website.pages.reduce(0) { $0 + $1.comments.count }

            return WebsiteWithStatsDTO(
                id: website.id,
                name: website.name,
                domain: website.domain,
                createdAt: website.createdAt,
                pageCount: pageCount,
                commentCount: commentCount
            )
        }
    }

    @Sendable
    func create(req: Request) async throws -> WebsiteDTO {
        let user = try req.auth.require(User.self)
        let createWebsite = try req.content.decode(CreateWebsiteDTO.self)

        let website = createWebsite.toModel(userId: try user.requireID())
        try await website.save(on: req.db)

        return website.toDTO()
    }

    @Sendable
    func show(req: Request) async throws -> WebsiteDTO {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        guard let website = try await Website.find(req.parameters.get("websiteID"), on: req.db) else {
            throw Abort(.notFound)
        }

        guard website.$user.id == userID else {
            throw Abort(.forbidden)
        }

        return website.toDTO()
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        guard let website = try await Website.find(req.parameters.get("websiteID"), on: req.db) else {
            throw Abort(.notFound)
        }

        guard website.$user.id == userID else {
            throw Abort(.forbidden)
        }

        try await website.delete(on: req.db)
        return .noContent
    }

    @Sendable
    func pages(req: Request) async throws -> View {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        guard let website = try await Website.find(req.parameters.get("websiteID"), on: req.db) else {
            throw Abort(.notFound)
        }

        guard website.$user.id == userID else {
            throw Abort(.forbidden)
        }

        let pages = try await Page.query(on: req.db)
            .filter(\.$website.$id == website.requireID())
            .with(\.$comments)
            .all()

        let pagesData = pages.map { page in
            PageWithCommentsDTO(
                id: page.id,
                url: page.url,
                createdAt: page.createdAt,
                commentCount: page.comments.count
            )
        }

        struct PagesContext: Encodable {
            let user: UserDTO
            let website: WebsiteDTO
            let pages: [PageWithCommentsDTO]
        }

        let context = PagesContext(
            user: user.toDTO(),
            website: website.toDTO(),
            pages: pagesData
        )

        return try await req.view.render("pages", context)
    }

    @Sendable
    func comments(req: Request) async throws -> View {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        guard let website = try await Website.find(req.parameters.get("websiteID"), on: req.db) else {
            throw Abort(.notFound)
        }

        guard website.$user.id == userID else {
            throw Abort(.forbidden)
        }

        let pages = try await Page.query(on: req.db)
            .filter(\.$website.$id == website.requireID())
            .with(\.$comments)
            .all()

        struct CommentWithPage: Encodable {
            let id: UUID?
            let pageUrl: String
            let authorName: String?
            let content: String
            let status: String
            let moderationResult: String?
            let createdAt: Date?
        }

        let commentsWithPages = pages.flatMap { page -> [CommentWithPage] in
            page.comments.map { comment in
                CommentWithPage(
                    id: comment.id,
                    pageUrl: page.url,
                    authorName: comment.authorName,
                    content: comment.content,
                    status: comment.status.rawValue,
                    moderationResult: comment.moderationResult,
                    createdAt: comment.createdAt
                )
            }
        }.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }

        struct CommentsContext: Encodable {
            let user: UserDTO
            let website: WebsiteDTO
            let comments: [CommentWithPage]
        }

        let context = CommentsContext(
            user: user.toDTO(),
            website: website.toDTO(),
            comments: commentsWithPages
        )

        return try await req.view.render("comments", context)
    }
}
