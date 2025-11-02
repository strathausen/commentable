import Fluent
import Vapor

struct EmbedController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let embed = routes.grouped("embed", ":websiteID")

        embed.get(use: self.showComments)
        embed.post("comment", use: self.postComment)
    }

    @Sendable
    func showComments(req: Request) async throws -> Response {
        guard let websiteID: UUID = req.parameters.get("websiteID") else {
            throw Abort(.badRequest)
        }

        // Get URL from query parameter
        let url = try req.query.get(String.self, at: "url")

        guard let website = try await Website.find(websiteID, on: req.db) else {
            throw Abort(.notFound, reason: "Website not found")
        }

        // Find or create page
        let page: Page
        if let existingPage = try await Page.query(on: req.db)
            .filter(\.$website.$id == websiteID)
            .filter(\.$url == url)
            .first() {
            page = existingPage
        } else {
            page = Page(websiteID: websiteID, url: url)
            try await page.save(on: req.db)
        }

        // Get approved comments for this page
        let comments = try await Comment.query(on: req.db)
            .filter(\.$page.$id == page.requireID())
            .filter(\.$status == .approved)
            .sort(\.$createdAt, .ascending)
            .all()

        let publicComments = comments.map { comment in
            PublicCommentDTO(
                id: comment.id,
                authorName: comment.authorName,
                content: comment.content,
                createdAt: comment.createdAt
            )
        }

        // Render the embed view
        struct EmbedContext: Encodable {
            let websiteId: String
            let url: String
            let comments: [PublicCommentDTO]
            let websiteDomain: String
        }

        let context = EmbedContext(
            websiteId: websiteID.uuidString,
            url: url,
            comments: publicComments,
            websiteDomain: website.domain
        )
        return try await req.view.render("embed", context).encodeResponse(for: req)
    }

    @Sendable
    func postComment(req: Request) async throws -> Response {
        guard let websiteID: UUID = req.parameters.get("websiteID") else {
            throw Abort(.badRequest)
        }

        struct PostCommentRequest: Content {
            let url: String
            let authorName: String?
            let content: String
        }

        let postRequest = try req.content.decode(PostCommentRequest.self)

        guard let _ = try await Website.find(websiteID, on: req.db) else {
            throw Abort(.notFound, reason: "Website not found")
        }

        // Find or create page
        let page: Page
        if let existingPage = try await Page.query(on: req.db)
            .filter(\.$website.$id == websiteID)
            .filter(\.$url == postRequest.url)
            .first() {
            page = existingPage
        } else {
            page = Page(websiteID: websiteID, url: postRequest.url)
            try await page.save(on: req.db)
        }

        // Create comment
        let comment = Comment(
            pageID: try page.requireID(),
            authorName: postRequest.authorName,
            content: postRequest.content
        )

        try await comment.save(on: req.db)

        // Get active moderation prompts
        let prompts = try await ModerationPrompt.query(on: req.db)
            .filter(\.$website.$id == websiteID)
            .filter(\.$isActive == true)
            .all()

        let customPrompts = prompts.map { $0.prompt }

        // Run moderation
        do {
            let (approved, result) = try await req.moderation.moderateComment(comment, customPrompts: customPrompts)
            comment.status = approved ? .approved : .rejected
            comment.moderationResult = result
            comment.moderatedAt = Date()
            try await comment.save(on: req.db)
        } catch {
            req.logger.error("Moderation failed: \(error)")
            comment.status = .rejected
            comment.moderationResult = "Moderation system error"
            comment.moderatedAt = Date()
            try await comment.save(on: req.db)
        }

        // Return response
        if comment.status == .approved {
            return try await req.view.render("comment-item", [
                "comment": PublicCommentDTO(
                    id: comment.id,
                    authorName: comment.authorName,
                    content: comment.content,
                    createdAt: comment.createdAt
                )
            ]).encodeResponse(for: req)
        } else {
            throw Abort(.badRequest, reason: "Comment rejected by moderation")
        }
    }
}
