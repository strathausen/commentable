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
            website.patch(use: self.update)
            website.delete(use: self.delete)
            website.post("archive", use: self.archive)
            website.post("restore", use: self.restore)
            website.get("pages", use: self.pages)
            website.get("comments", use: self.comments)
            website.post("comments", ":commentID", "moderate", use: self.moderateComment)
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
    func show(req: Request) async throws -> View {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        guard let website = try await Website.find(req.parameters.get("websiteID"), on: req.db) else {
            throw Abort(.notFound)
        }

        guard website.$user.id == userID else {
            throw Abort(.forbidden)
        }

        // Load pages with comments
        let pages = try await Page.query(on: req.db)
            .filter(\.$website.$id == website.requireID())
            .with(\.$comments)
            .all()

        let pagesData = pages.map { page in
            PageWithCommentsDTO(
                id: page.id,
                path: page.path,
                createdAt: page.createdAt,
                commentCount: page.comments.count
            )
        }

        // Load comments with page info
        struct CommentWithPage: Encodable {
            let id: UUID?
            let pagePath: String
            let authorName: String?
            let content: String
            let status: String
            let moderationResult: String?
            let createdAt: Date?
            let manuallyModerated: Bool
        }

        let commentsWithPages = pages.flatMap { page -> [CommentWithPage] in
            page.comments.map { comment in
                CommentWithPage(
                    id: comment.id,
                    pagePath: page.path,
                    authorName: comment.authorName,
                    content: comment.content,
                    status: comment.status.rawValue,
                    moderationResult: comment.moderationResult,
                    createdAt: comment.createdAt,
                    manuallyModerated: comment.manuallyModerated
                )
            }
        }.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }

        // Load prompts
        let prompts = try await ModerationPrompt.query(on: req.db)
            .filter(\.$website.$id == website.requireID())
            .sort(\.$createdAt, .descending)
            .all()

        // Generate embed code
        let baseURL = req.application.http.server.configuration.hostname
        let port = req.application.http.server.configuration.port
        let scheme = req.application.environment == .development ? "http" : "https"

        let embedBaseURL: String
        if port == 80 || port == 443 {
            embedBaseURL = "\(scheme)://\(baseURL)/embed/\(website.id?.uuidString ?? "")"
        } else {
            embedBaseURL = "\(scheme)://\(baseURL):\(port)/embed/\(website.id?.uuidString ?? "")"
        }

        let embedCode = """
        <iframe
          src="\(embedBaseURL)?path="
          width="100%"
          height="600"
          frameborder="0">
        </iframe>
        <script>
          (function() {
            var iframe = document.currentScript.previousElementSibling;
            var path = window.location.pathname;
            iframe.src = iframe.src + encodeURIComponent(path);
          })();
        </script>
        """

        let standaloneLink = "\(embedBaseURL)?path="

        struct WebsiteDetailContext: Encodable {
            let user: UserDTO
            let website: WebsiteDTO
            let pages: [PageWithCommentsDTO]
            let comments: [CommentWithPage]
            let prompts: [ModerationPromptDTO]
            let pageCount: Int
            let commentCount: Int
            let promptCount: Int
            let embedCode: String
            let standaloneLink: String
        }

        let context = WebsiteDetailContext(
            user: user.toDTO(),
            website: website.toDTO(),
            pages: pagesData,
            comments: commentsWithPages,
            prompts: prompts.map { $0.toDTO() },
            pageCount: pages.count,
            commentCount: commentsWithPages.count,
            promptCount: prompts.count,
            embedCode: embedCode,
            standaloneLink: standaloneLink
        )

        return try await req.view.render("website-detail", context)
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
    func update(req: Request) async throws -> Response {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        guard let website = try await Website.find(req.parameters.get("websiteID"), on: req.db) else {
            throw Abort(.notFound)
        }

        guard website.$user.id == userID else {
            throw Abort(.forbidden)
        }

        struct UpdateWebsiteDTO: Content {
            let name: String?
            let domain: String?
        }

        let update = try req.content.decode(UpdateWebsiteDTO.self)

        if let name = update.name {
            website.name = name
        }
        if let domain = update.domain {
            website.domain = domain
        }

        try await website.save(on: req.db)

        return Response(status: .ok)
    }

    @Sendable
    func archive(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        guard let website = try await Website.find(req.parameters.get("websiteID"), on: req.db) else {
            throw Abort(.notFound)
        }

        guard website.$user.id == userID else {
            throw Abort(.forbidden)
        }

        website.archived = true
        try await website.save(on: req.db)
        return .noContent
    }

    @Sendable
    func restore(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        guard let website = try await Website.find(req.parameters.get("websiteID"), on: req.db) else {
            throw Abort(.notFound)
        }

        guard website.$user.id == userID else {
            throw Abort(.forbidden)
        }

        website.archived = false
        try await website.save(on: req.db)
        return .noContent
    }

    @Sendable
    func moderateComment(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        guard let website = try await Website.find(req.parameters.get("websiteID"), on: req.db) else {
            throw Abort(.notFound)
        }

        guard website.$user.id == userID else {
            throw Abort(.forbidden)
        }

        guard let comment = try await Comment.find(req.parameters.get("commentID"), on: req.db) else {
            throw Abort(.notFound)
        }

        struct ModerateCommentDTO: Content {
            let status: String
        }

        let moderation = try req.content.decode(ModerateCommentDTO.self)

        if let newStatus = CommentStatus(rawValue: moderation.status) {
            comment.status = newStatus
            comment.manuallyModerated = true
            comment.moderatedAt = Date()
            comment.moderationResult = "Manually moderated by owner"
            try await comment.save(on: req.db)
        }

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
                path: page.path,
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
            let pagePath: String
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
                    pagePath: page.path,
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
